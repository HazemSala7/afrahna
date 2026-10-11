# Read-only diagnosis of the API outage: how full is the account, and has
# anything written a fresh error log since the 500s started.
$ErrorActionPreference = 'Continue'
$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)

$q   = Join-Path $PSScriptRoot 'logs\q.txt'
$err = Join-Path $PSScriptRoot 'logs\admin-error-log.txt'
$script = Join-Path $env:TEMP 'afrahna-diag.txt'

Set-Content -Path $script -Encoding UTF8 -Value @(
  'option batch continue'
  'option confirm off'
  "open ftpes://${u}:${p}@$($cred.host):$($cred.port) -explicit -certificate=*"
  "get -nopermissions ""/.ftpquota"" ""$q"""
  "get -nopermissions ""/public_html/admin/error_log"" ""$err"""
  'close'
  'exit'
)

& $winscp "/script=$script" "/loglevel=0" "/ini=nul"

if (Test-Path $q) {
  $v = (Get-Content $q -Raw).Trim() -split '\s+'
  "QUOTA NOW: {0} files, {1:N2} GB" -f $v[0], ([int64]$v[1] / 1GB)
}
if (Test-Path $err) {
  "=== tail of admin/public/error_log ==="
  Get-Content $err -Tail 40
}
