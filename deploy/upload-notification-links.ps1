# Uploads the controllers changed so every notification carries a link the app
# can navigate with. Same FTPS credentials as deploy-laravel.ps1, only the
# named files — nothing unrelated is pushed to production.
$ErrorActionPreference = 'Stop'

$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
$repo   = 'D:\Apps\Afrahna\afrahna'
$local  = Join-Path $repo 'server-admin'
$cred   = Get-Content (Join-Path $repo 'deploy\.ftp-credentials.json') -Raw | ConvertFrom-Json
$remote = '/public_html/admin'

Add-Type -AssemblyName System.Web
$encUser = [System.Web.HttpUtility]::UrlEncode($cred.username)
$encPass = [System.Web.HttpUtility]::UrlEncode($cred.password)
$openLine = "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"

$files = @(
  'app/Http/Controllers/Api/InvitationController.php',
  'app/Http/Controllers/Api/FollowController.php',
  'app/Http/Controllers/Api/PostCommentController.php',
  'app/Http/Controllers/Api/PostController.php',
  'app/Http/Controllers/Api/ReviewController.php',
  'app/Http/Controllers/Api/VendorController.php'
)

$lines = @(
  'option batch abort'
  'option confirm off'
  'option transfer binary'
  $openLine
)
foreach ($f in $files) {
  $src = Join-Path $local ($f -replace '/', '\')
  if (-not (Test-Path $src)) { throw "missing local file: $src" }
  $lines += "put -nopermissions -nopreservetime `"$src`" `"$remote/$f`""
}
$lines += @('close', 'exit')

$scriptFile = Join-Path $env:TEMP 'afrahna-notification-links-upload.txt'
Set-Content -Path $scriptFile -Value $lines -Encoding UTF8

& $winscp "/script=$scriptFile" "/log=$env:TEMP\afrahna-upload.log" "/loglevel=1" "/ini=nul"
Write-Host "WinSCP exit code: $LASTEXITCODE"
exit $LASTEXITCODE
