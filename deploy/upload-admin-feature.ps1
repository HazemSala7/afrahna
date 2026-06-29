#
# Targeted upload of the admin-control + admin-notifications backend changes.
# Creates app/Support remotely (new dir), uploads the changed files, then
# clears the opcache so the new code is served immediately.
#
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

$winscpCandidates = @(
    "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com",
    "C:\Program Files\WinSCP\WinSCP.com",
    "C:\Program Files (x86)\WinSCP\WinSCP.com"
)
$winscp = $winscpCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $winscp) { throw "WinSCP.com not found" }

$repoRoot = Split-Path -Parent $PSScriptRoot
$credPath = Join-Path $PSScriptRoot '.ftp-credentials.json'
$cred     = Get-Content $credPath -Raw | ConvertFrom-Json
$remote   = '/public_html/admin'

Add-Type -AssemblyName System.Web
$encUser = [System.Web.HttpUtility]::UrlEncode($cred.username)
$encPass = [System.Web.HttpUtility]::UrlEncode($cred.password)

$timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir     = Join-Path $PSScriptRoot 'logs'
$logFile    = Join-Path $logDir "admin-feature-$timestamp.log"
$scriptFile = Join-Path $logDir "admin-feature-$timestamp.txt"

$files = @(
    'app/Support/AdminNotifier.php',
    'app/Http/Controllers/Api/AuthController.php',
    'app/Http/Controllers/Api/BookingController.php',
    'app/Http/Controllers/Api/ReviewController.php',
    'app/Http/Controllers/Api/PostCommentController.php',
    'app/Http/Controllers/Api/DelegateController.php',
    'app/Http/Controllers/Api/VendorController.php'
)

$lines = @(
    'option batch continue'
    'option confirm off'
    'option transfer binary'
    "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"
    # Ensure the new Support directory exists (ignored if it already does).
    "mkdir ""$remote/app/Support"""
)
foreach ($f in $files) {
    $local      = (Join-Path $repoRoot "server-admin/$f").Replace('/', '\')
    $remoteFile = "$remote/$f"
    $lines += "put -nopermissions -nopreservetime ""$local"" ""$remoteFile"""
}
$lines += @('close','exit')

Set-Content -Path $scriptFile -Value $lines -Encoding UTF8
& $winscp "/script=$scriptFile" "/log=$logFile" "/loglevel=1" "/ini=nul"
Write-Host "WinSCP exit: $LASTEXITCODE"
