#
# Targeted upload of the owner-scoping ("mine") fix for the content screen:
#   - ServiceController (services?mine=1 -> owner's services)
#   - PostController    (posts?mine=1    -> owner's reels)
# Both resolve the Bearer token via the sanctum guard on their public routes.
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
$logFile    = Join-Path $logDir "mine-fix-$timestamp.log"
$scriptFile = Join-Path $logDir "mine-fix-$timestamp.txt"

$files = @(
    'app/Http/Controllers/Api/ServiceController.php',
    'app/Http/Controllers/Api/PostController.php'
)

$lines = @(
    'option batch abort'
    'option confirm off'
    'option transfer binary'
    "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"
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
