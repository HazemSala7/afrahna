<#
.SYNOPSIS
    Deploy the Laravel backend (afrahna-admin) to shared hosting via FTPS Explicit using WinSCP.

.DESCRIPTION
    - Reads FTP credentials from deploy/.ftp-credentials.json (gitignored).
    - Uses WinSCP "synchronize remote" so only changed files are uploaded.
    - Honors exclude list in deploy/laravel-exclude.txt.
    - Uploads .htaccess root rewrite (so /admin -> /admin/public).
    - Logs full session output to deploy/logs/.

.PARAMETER DryRun
    If specified, performs a preview only (no actual file transfers).

.PARAMETER FirstRun
    If specified, accepts the server TLS certificate fingerprint on first connect
    and writes it back to .ftp-credentials.json for future runs.

.EXAMPLE
    pwsh -File deploy/deploy-laravel.ps1 -FirstRun -DryRun
    pwsh -File deploy/deploy-laravel.ps1
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$FirstRun
)

$ErrorActionPreference = 'Stop'

# --- Locate WinSCP -----------------------------------------------------------
$winscpCandidates = @(
    "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com",
    "C:\Program Files\WinSCP\WinSCP.com",
    "C:\Program Files (x86)\WinSCP\WinSCP.com"
)
$winscp = $winscpCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $winscp) {
    throw "WinSCP.com not found. Install via: winget install WinSCP.WinSCP"
}

# --- Paths -------------------------------------------------------------------
$repoRoot   = Split-Path -Parent $PSScriptRoot
$localPath  = Join-Path $repoRoot 'server-admin'
$credPath   = Join-Path $PSScriptRoot '.ftp-credentials.json'
$excludeTxt = Join-Path $PSScriptRoot 'laravel-exclude.txt'
$htaccess   = Join-Path $PSScriptRoot 'htaccess-root.txt'
$logDir     = Join-Path $PSScriptRoot 'logs'
$timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile    = Join-Path $logDir "deploy-$timestamp.log"
$scriptFile = Join-Path $logDir "session-$timestamp.txt"

foreach ($p in @($localPath, $credPath, $excludeTxt, $htaccess)) {
    if (-not (Test-Path $p)) { throw "Missing required path: $p" }
}

# --- Credentials -------------------------------------------------------------
$cred = Get-Content $credPath -Raw | ConvertFrom-Json
$remotePath = '/public_html/admin'

# URL-encode credentials for open URI
Add-Type -AssemblyName System.Web
$encUser = [System.Web.HttpUtility]::UrlEncode($cred.username)
$encPass = [System.Web.HttpUtility]::UrlEncode($cred.password)

$openOptions = @('-explicit')
if ($cred.tlsHostCertificateFingerprint) {
    $openOptions += "-certificate=""$($cred.tlsHostCertificateFingerprint)"""
} else {
    # Accept any TLS cert. Auth still relies on username+password over the encrypted channel.
    # Run with -FirstRun once to capture and pin the real fingerprint.
    $openOptions += '-certificate=*'
}

$openLine = "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) $($openOptions -join ' ')"

# --- Build exclude mask ------------------------------------------------------
$excludeMask = (Get-Content $excludeTxt | Where-Object { $_ -and -not $_.StartsWith('#') }) -join ''
$excludeMask = $excludeMask.Trim()

# --- Compose WinSCP script ---------------------------------------------------
$syncMode = if ($DryRun) { 'synchronize remote -preview' } else { 'synchronize remote' }

$scriptLines = @(
    'option batch abort'
    'option confirm off'
    'option reconnecttime 30'
    'option transfer binary'
    $openLine
    "option exclude ""$excludeMask"""
    # Ensure remote dir exists; tolerate "already exists" error
    'option batch continue'
    "mkdir $remotePath"
    'option batch abort'
    # Sync local Laravel app -> remote (mirror mode, no remote deletes for safety)
    "$syncMode -mirror -delete=off -criteria=time -nopermissions -nopreservetime ""$localPath"" ""$remotePath"""
)
if (-not $DryRun) {
    $scriptLines += "put -nopermissions -nopreservetime ""$htaccess"" ""$remotePath/.htaccess"""
}
$scriptLines += @(
    'close'
    'exit'
)

Set-Content -Path $scriptFile -Value $scriptLines -Encoding UTF8

Write-Host "WinSCP        : $winscp" -ForegroundColor DarkGray
Write-Host "Local source  : $localPath" -ForegroundColor DarkGray
Write-Host "Remote target : ftpes://$($cred.host):$($cred.port)$remotePath" -ForegroundColor DarkGray
Write-Host "Script file   : $scriptFile" -ForegroundColor DarkGray
Write-Host "Log file      : $logFile" -ForegroundColor DarkGray
$modeLabel = if ($DryRun) { 'DRY RUN (preview only)' } else { 'LIVE UPLOAD' }
Write-Host "Mode          : $modeLabel" -ForegroundColor Yellow

# --- Execute -----------------------------------------------------------------
& $winscp `
    "/script=$scriptFile" `
    "/log=$logFile" `
    "/loglevel=2" `
    "/ini=nul"

$exit = $LASTEXITCODE
$exitColor = if ($exit -eq 0) { 'Green' } else { 'Red' }
Write-Host "WinSCP exit code: $exit" -ForegroundColor $exitColor

# --- Capture fingerprint on first run ---------------------------------------
if ($FirstRun -and (Test-Path $logFile)) {
    $logText = Get-Content $logFile -Raw
    $m = [regex]::Match($logText, 'fingerprint(?:\s+is)?\s*[:=]\s*([0-9a-fA-F:]{47,})')
    if (-not $m.Success) {
        $m = [regex]::Match($logText, '([0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){31,})')
    }
    if ($m.Success) {
        $cred.tlsHostCertificateFingerprint = $m.Groups[1].Value
        ($cred | ConvertTo-Json -Depth 5) | Set-Content $credPath -Encoding UTF8
        Write-Host "Saved TLS fingerprint to credentials file: $($m.Groups[1].Value)" -ForegroundColor Green
    } else {
        Write-Warning "Could not auto-extract TLS fingerprint from log. Open $logFile and paste it into $credPath manually."
    }
}

exit $exit
