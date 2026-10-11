# EMERGENCY RESTORE
#
# The live API returns 500 on every request because Laravel's autoloader cannot
# find vendor/guzzlehttp/guzzle/src/functions_include.php. Composer's autoload
# requires it unconditionally, so one missing file takes the whole application
# down.
#
# This uploads the guzzlehttp packages from the local vendor/ — the same
# versions composer.lock pins — into place. Nothing else is touched.
$ErrorActionPreference = 'Stop'

$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
if (-not (Test-Path $winscp)) { $winscp = "C:\Program Files (x86)\WinSCP\WinSCP.com" }

$repoRoot = Split-Path -Parent $PSScriptRoot
$local    = Join-Path $repoRoot 'server-admin\vendor\guzzlehttp'
if (-not (Test-Path (Join-Path $local 'guzzle\src\functions_include.php'))) {
    throw "Local guzzle copy is missing at $local"
}

$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)

$remote = '/public_html/admin/vendor'
$logDir = Join-Path $PSScriptRoot 'logs'
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$script = Join-Path $logDir "restore-$stamp.txt"
$log    = Join-Path $logDir "restore-$stamp.log"

Set-Content -Path $script -Encoding UTF8 -Value @(
    'option batch abort'
    'option confirm off'
    'option transfer binary'
    'option reconnecttime 30'
    "open ftpes://${u}:${p}@$($cred.host):$($cred.port) -explicit -certificate=*"
    'option batch continue'
    'option batch abort'
    # Upload-only: never delete anything already on the server.
    # No -delete and no -mirror: WinSCP treats -delete as a presence flag, so
    # "-delete=off" ENABLES deletion. Plain `synchronize remote` only adds and
    # updates, which is all a restore may ever do.
    "synchronize remote -criteria=none -nopermissions -nopreservetime ""$local"" ""$remote"""
    'close'
    'exit'
)

# -criteria=none compares by existence alone, so files already on the server
# are skipped and only the missing ones go up. On a full disk that matters.
Write-Host "Restoring missing files: $local  ->  $remote"
& $winscp "/script=$script" "/log=$log" "/loglevel=1" "/ini=nul"
Write-Host "WinSCP exit code: $LASTEXITCODE"
exit $LASTEXITCODE
