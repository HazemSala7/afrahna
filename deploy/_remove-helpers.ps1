# Removes the two deploy helpers by exact path. Named deletions only — no
# wildcard, no synchronize, no -mirror.
$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
if (-not (Test-Path $winscp)) { $winscp = "C:\Program Files (x86)\WinSCP\WinSCP.com" }
$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)
$s = Join-Path $env:TEMP 'afrahna-rmhelpers.txt'
Set-Content -Path $s -Encoding UTF8 -Value @(
  'option batch continue','option confirm off'
  "open ftpes://${u}:${p}@$($cred.host):$($cred.port) -explicit -certificate=*"
  'rm /public_html/_site.zip'
  'rm /public_html/_extract.php'
  'close','exit')
& $winscp "/script=$s" "/loglevel=0" "/ini=nul"
