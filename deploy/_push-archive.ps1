# Uploads the site archive and its extractor to the afrahna.co web root.
# Two explicit puts. No synchronize, no -mirror, no -delete: this cannot remove
# anything, which matters because this account also holds the live API.
$ErrorActionPreference = 'Stop'
$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
if (-not (Test-Path $winscp)) { $winscp = "C:\Program Files (x86)\WinSCP\WinSCP.com" }
$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)

$zip = Join-Path $PSScriptRoot '_site.zip'
$php = Join-Path $PSScriptRoot '_extract.php'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$log = Join-Path $PSScriptRoot "logs\archive-$stamp.log"
$s = Join-Path $env:TEMP 'afrahna-push.txt'
Set-Content -Path $s -Encoding UTF8 -Value @(
  'option batch abort'
  'option confirm off'
  'option transfer binary'
  'option reconnecttime 30'
  "open ftpes://${u}:${p}@$($cred.host):$($cred.port) -explicit -certificate=*"
  "put -nopermissions ""$zip"" ""/public_html/_site.zip"""
  "put -nopermissions ""$php"" ""/public_html/_extract.php"""
  'close'
  'exit'
)
& $winscp "/script=$s" "/log=$log" "/loglevel=1" "/ini=nul"
Write-Host "exit code: $LASTEXITCODE"
Write-Host "deletions in log: $((Select-String -Path $log -Pattern 'DELE ' -AllMatches).Count)  <- must be 0"
