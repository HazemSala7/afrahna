# Can the account accept a single small file right now?
$ErrorActionPreference = 'Stop'
$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)
$probe = Join-Path $env:TEMP 'afrahna-space-probe.txt'
Set-Content -Path $probe -Value 'probe' -Encoding ASCII
$dest = Join-Path $PSScriptRoot 'logs\quota-now.txt'
$script = Join-Path $env:TEMP 'afrahna-space-test.txt'
Set-Content -Path $script -Encoding UTF8 -Value @(
  'option batch continue'
  'option confirm off'
  "open ftpes://${u}:${p}@$($cred.host):$($cred.port) -explicit -certificate=*"
  "get -nopermissions ""/.ftpquota"" ""$dest"""
  "put -nopermissions ""$probe"" ""/public_html/_spacetest.txt"""
  'rm /public_html/_spacetest.txt'
  'close'
  'exit'
)
& $winscp "/script=$script" "/loglevel=0" "/ini=nul"
if (Test-Path $dest) {
  $q = (Get-Content $dest -Raw).Trim() -split '\s+'
  $bytes = [int64]$q[1]
  "QUOTA: {0} files, {1:N2} GB used" -f $q[0], ($bytes / 1GB)
}
