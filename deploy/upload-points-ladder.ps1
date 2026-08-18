# Uploads the rewards ladder and its notifications: the pure rules class, the
# points engine, the claim endpoint and its route, the daily-login touch in
# /auth/me, the subscription award hook, the notifier that announces every
# award, and the migrations behind all of it.
#
# AFTER UPLOADING, RUN THE MIGRATION — claiming a reward writes to tables and
# columns that do not exist until it has run:
#   deploy\run-migrate.ps1
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
  'app/Services/PointsRules.php',
  'app/Support/PointsNotifier.php',
  'app/Support/UserNotifier.php',
  'app/Services/PointsService.php',
  'app/Models/PointReward.php',
  'app/Models/Subscription.php',
  'app/Http/Controllers/Api/PointController.php',
  'app/Http/Controllers/Api/AuthController.php',
  'app/Http/Controllers/Api/ReviewController.php',
  'routes/api.php',
  'database/migrations/2026_08_18_000001_rewards_ladder.php',
  'database/migrations/2026_08_18_000002_points_notifications.php'
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

$scriptFile = Join-Path $env:TEMP 'afrahna-points-ladder-upload.txt'
Set-Content -Path $scriptFile -Value $lines -Encoding UTF8

& $winscp "/script=$scriptFile" "/log=$env:TEMP\afrahna-upload.log" "/loglevel=1" "/ini=nul"
Write-Host "WinSCP exit code: $LASTEXITCODE"
Write-Host "Now run the migration:  deploy\run-migrate.ps1"
Write-Host "Then clear the opcache:  deploy\reset-opcache.ps1"
exit $LASTEXITCODE
