# Uploads the server side of guest invitations: the public create/read routes,
# the claim endpoint, and the migration that lets an invitation exist without
# an owner.
#
# AFTER UPLOADING, RUN THE MIGRATION — the new column state is what makes an
# ownerless invitation insertable at all:
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
  'app/Http/Controllers/Api/InvitationController.php',
  'routes/api.php',
  'database/migrations/2026_08_15_000001_allow_guest_invitations.php'
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

$scriptFile = Join-Path $env:TEMP 'afrahna-guest-invitations-upload.txt'
Set-Content -Path $scriptFile -Value $lines -Encoding UTF8

& $winscp "/script=$scriptFile" "/log=$env:TEMP\afrahna-upload.log" "/loglevel=1" "/ini=nul"
Write-Host "WinSCP exit code: $LASTEXITCODE"
Write-Host "Now run the migration:  deploy\run-migrate.ps1"
exit $LASTEXITCODE
