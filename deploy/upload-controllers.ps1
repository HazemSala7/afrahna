#
# Targeted upload of just the modified Api controllers (no vendor sync).
# Use this for hotfix deploys when you don't want a full synchronize.
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
$logFile    = Join-Path $logDir "hotfix-$timestamp.log"
$scriptFile = Join-Path $logDir "hotfix-$timestamp.txt"

$files = @(
    'app/Http/Controllers/Api/UserController.php',
    'app/Http/Controllers/Api/BookingController.php',
    'app/Http/Controllers/Api/DelegateController.php',
    'app/Http/Controllers/Api/ServiceController.php',
    'app/Http/Controllers/Api/PromotionController.php',
    'app/Models/User.php'
)

$lines = @(
    'option batch abort'
    'option confirm off'
    'option transfer binary'
    "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"
)
foreach ($f in $files) {
    $local  = (Join-Path $repoRoot "server-admin/$f").Replace('/', '\')
    $remoteFile = "$remote/$f"
    $lines += "put -nopermissions -nopreservetime ""$local"" ""$remoteFile"""
}
$lines += @('close','exit')

Set-Content -Path $scriptFile -Value $lines -Encoding UTF8
& $winscp "/script=$scriptFile" "/log=$logFile" "/loglevel=1" "/ini=nul"
exit $LASTEXITCODE
