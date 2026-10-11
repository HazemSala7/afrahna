# Read-only: size up the usual suspects on a full account.
$ErrorActionPreference = 'Continue'
$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)
$script = Join-Path $env:TEMP 'afrahna-find-space.txt'
Set-Content -Path $script -Encoding UTF8 -Value @(
  'option batch continue'
  'option confirm off'
  "open ftpes://${u}:${p}@$($cred.host):$($cred.port) -explicit -certificate=*"
  'echo === POSTS ==='
  'ls /public_html/admin/public/uploads/posts'
  'echo === VENDORS ==='
  'ls /public_html/admin/public/uploads/vendors'
  'echo === PRODUCTS ==='
  'ls /public_html/admin/public/uploads/products'
  'close'
  'exit'
)
& $winscp "/script=$script" "/loglevel=0" "/ini=nul"
