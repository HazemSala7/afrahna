# Uploads the public invitation page (https://afrahna.co/i/{CODE}).
#
# That page is a single standalone PHP file served from /public_html/i — it is
# not part of the Laravel app, so deploy-laravel.ps1 never touches it. Same
# FTPS credentials, one file.
$ErrorActionPreference = 'Stop'

$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
$repo   = 'D:\Apps\Afrahna\afrahna'
$cred   = Get-Content (Join-Path $repo 'deploy\.ftp-credentials.json') -Raw | ConvertFrom-Json
$src    = Join-Path $repo 'deploy\web-i\index.php'
$dst    = '/public_html/i/index.php'

if (-not (Test-Path $src)) { throw "missing local file: $src" }

Add-Type -AssemblyName System.Web
$encUser = [System.Web.HttpUtility]::UrlEncode($cred.username)
$encPass = [System.Web.HttpUtility]::UrlEncode($cred.password)

$lines = @(
  'option batch abort'
  'option confirm off'
  'option transfer binary'
  "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"
  "put -nopermissions -nopreservetime `"$src`" `"$dst`""
  'close'
  'exit'
)

$scriptFile = Join-Path $env:TEMP 'afrahna-invitation-upload.txt'
Set-Content -Path $scriptFile -Value $lines -Encoding UTF8

& $winscp "/script=$scriptFile" "/log=$env:TEMP\afrahna-upload.log" "/loglevel=1" "/ini=nul"
Write-Host "WinSCP exit code: $LASTEXITCODE"
exit $LASTEXITCODE
