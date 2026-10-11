# Read-only: what already lives at the afrahna.co web root, before we add a
# site on top of it.
$ErrorActionPreference = 'Stop'
$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)
$script = Join-Path $env:TEMP 'afrahna-co-list.txt'
Set-Content -Path $script -Encoding UTF8 -Value @(
  'option batch abort'
  'option confirm off'
  "open ftpes://${u}:${p}@$($cred.host):$($cred.port) -explicit -certificate=*"
  'ls /public_html'
  'close'
  'exit'
)
& $winscp "/script=$script" "/loglevel=0" "/ini=nul"
