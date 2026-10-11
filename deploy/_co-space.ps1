$ErrorActionPreference = 'Stop'
$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)
$dest = Join-Path $PSScriptRoot 'logs\co-ftpquota.txt'
$script = Join-Path $env:TEMP 'afrahna-co-space.txt'
Set-Content -Path $script -Encoding UTF8 -Value @(
  'option batch abort'
  'option confirm off'
  "open ftpes://${u}:${p}@$($cred.host):$($cred.port) -explicit -certificate=*"
  'ls /'
  "get -nopermissions ""/.ftpquota"" ""$dest"""
  'close'
  'exit'
)
& $winscp "/script=$script" "/loglevel=0" "/ini=nul"
if (Test-Path $dest) { "QUOTA FILE: " + (Get-Content $dest -Raw) }
