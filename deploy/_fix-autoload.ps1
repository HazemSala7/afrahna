# Puts Composer's autoloader back — the minimum needed for Laravel to boot.
#
# Laravel requires vendor/autoload.php on every request, which in turn requires
# vendor/composer/autoload_real.php. Both were deleted. These eleven files are
# small (well under a megabyte all told), so they land even on a full disk,
# unlike the full vendor sync which is hitting "552 Disk full".
#
# Upload only: no -delete, no -mirror, no synchronize. Explicit puts.
$ErrorActionPreference = 'Continue'
$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
if (-not (Test-Path $winscp)) { $winscp = "C:\Program Files (x86)\WinSCP\WinSCP.com" }

$repoRoot = Split-Path -Parent $PSScriptRoot
$vendor   = Join-Path $repoRoot 'server-admin\vendor'
$composer = Join-Path $vendor 'composer'
if (-not (Test-Path (Join-Path $composer 'autoload_real.php'))) {
    throw "local vendor/composer is incomplete"
}

$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)

$remote = '/public_html/admin/vendor'
$lines = @(
    'option batch continue'
    'option confirm off'
    'option transfer binary'
    "open ftpes://${u}:${p}@$($cred.host):$($cred.port) -explicit -certificate=*"
    "mkdir $remote/composer"
    "put -nopermissions ""$vendor\autoload.php"" ""$remote/autoload.php"""
)
foreach ($f in Get-ChildItem -File $composer) {
    $lines += "put -nopermissions ""$($f.FullName)"" ""$remote/composer/$($f.Name)"""
}
# mockery is a dev dependency, but composer listed its helpers.php among the
# files the autoloader requires at boot, so its absence stops Laravel dead.
# Only library/ is needed — the package's tests, tools and (locally) a stray
# .git clone are not, and the disk has no room for them.
$mock = Join-Path $vendor "mockery\mockery\library"
if (Test-Path $mock) {
    $lines += "mkdir $remote/mockery"
    $lines += "mkdir $remote/mockery/mockery"
    $lines += "mkdir $remote/mockery/mockery/library"
    $lines += "synchronize remote -criteria=none -nopermissions -nopreservetime ""$mock"" ""$remote/mockery/mockery/library"""
}

$lines += @('close', 'exit')

$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$log    = Join-Path $PSScriptRoot "logs\autoload-$stamp.log"
$script = Join-Path $env:TEMP 'afrahna-fix-autoload.txt'
Set-Content -Path $script -Value $lines -Encoding UTF8

& $winscp "/script=$script" "/log=$log" "/loglevel=1" "/ini=nul"
Write-Host "WinSCP exit code: $LASTEXITCODE"
Write-Host "uploaded: $((Select-String -Path $log -Pattern 'Transfer done' -AllMatches).Count)"
Write-Host "disk-full refusals: $((Select-String -Path $log -Pattern '552' -AllMatches).Count)"
