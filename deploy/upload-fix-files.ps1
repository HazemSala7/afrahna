# Targeted upload of the files changed for the auto-growth + reel-repair fix.
# Uses the same FTPS credentials as deploy-laravel.ps1 but uploads only the
# named files, so nothing unrelated is pushed to production.
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
  'app/Models/Post.php',
  'app/Services/StatsAccrualService.php',
  'app/Services/VideoTranscodeService.php',
  'app/Http/Controllers/Api/StatsController.php',
  'app/Console/Commands/RepairReels.php',
  'database/migrations/2026_08_02_000001_fix_zero_auto_growth_rates.php',
  'public/_run_ops_a66cfe5d.php'
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
  $dst = "$remote/$f"
  $lines += "put -nopermissions -nopreservetime `"$src`" `"$dst`""
}
$lines += @('close', 'exit')

$scriptFile = Join-Path $env:TEMP 'afrahna-targeted-upload.txt'
Set-Content -Path $scriptFile -Value $lines -Encoding UTF8

& $winscp "/script=$scriptFile" "/log=$env:TEMP\afrahna-upload.log" "/loglevel=1" "/ini=nul"
Write-Host "WinSCP exit code: $LASTEXITCODE"
exit $LASTEXITCODE
