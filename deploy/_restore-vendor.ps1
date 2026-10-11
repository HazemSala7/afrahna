# Restores the vendor packages the bad mirror deleted.
#
# The failed run mirrored local vendor/guzzlehttp INTO remote vendor/ with
# deletion enabled, so it walked vendor/ alphabetically removing everything that
# wasn't part of guzzle: bin, brick, carbonphp, dflydev, doctrine, dragonmantank,
# egulias — stopping around fakerphp when it was killed. doctrine is loaded by
# classmap rather than autoload_files, which is why the boot probe missed it.
#
# UPLOAD ONLY. No -delete, no -mirror. -criteria=none compares by existence, so
# files already on the server are skipped and only missing ones are sent.
$ErrorActionPreference = 'Continue'
$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
if (-not (Test-Path $winscp)) { $winscp = "C:\Program Files (x86)\WinSCP\WinSCP.com" }

$repoRoot = Split-Path -Parent $PSScriptRoot
$vendor   = Join-Path $repoRoot 'server-admin\vendor'

# fakerphp is included because deletion was interrupted partway through it, so
# it may be incomplete on the server. -criteria=none makes that a no-op if not.
$packages = @('bin','brick','carbonphp','dflydev','doctrine','dragonmantank',
              'egulias','fakerphp')

$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)

$remote = '/public_html/admin/vendor'
$lines = @(
    'option batch continue'
    'option confirm off'
    'option transfer binary'
    'option reconnecttime 30'
    "open ftpes://${u}:${p}@$($cred.host):$($cred.port) -explicit -certificate=*"
)
foreach ($pkg in $packages) {
    $local = Join-Path $vendor $pkg
    if (-not (Test-Path $local)) { Write-Warning "local $pkg missing, skipping"; continue }
    $lines += "mkdir $remote/$pkg"
    $lines += "synchronize remote -criteria=none -nopermissions -nopreservetime ""$local"" ""$remote/$pkg"""
}
$lines += @('close', 'exit')

$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$log    = Join-Path $logDir "vendor-restore-$stamp.log"
$script = Join-Path $env:TEMP 'afrahna-restore-vendor.txt'
Set-Content -Path $script -Value $lines -Encoding UTF8

& $winscp "/script=$script" "/log=$log" "/loglevel=1" "/ini=nul"
Write-Host "WinSCP exit code: $LASTEXITCODE"
Write-Host "uploaded:  $((Select-String -Path $log -Pattern 'Transfer done' -AllMatches).Count)"
Write-Host "deletions: $((Select-String -Path $log -Pattern 'DELE ' -AllMatches).Count)   <- must be 0"
Write-Host "disk-full: $((Select-String -Path $log -Pattern '552' -AllMatches).Count)"
