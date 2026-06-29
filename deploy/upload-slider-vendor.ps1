#
# Targeted upload of the slider->vendor link change:
#   - new migration (adds sliders.vendor_id)
#   - Slider model (fillable + relation)
#   - SliderController (validate + present vendor_id)
# Run run-migrate.ps1 afterwards to apply the migration, then reset-opcache.ps1.
#
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

$winscpCandidates = @(
    "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com",
    "C:\Program Files\WinSCP\WinSCP.com",
    "C:\Program Files (x86)\WinSCP\WinSCP.com"
)
$winscp = $winscpCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $winscp) { throw "WinSCP.com not found" }

$repoRoot = Split-Path -Parent $PSScriptRoot
$credPath = Join-Path $PSScriptRoot '.ftp-credentials.json'
$cred     = Get-Content $credPath -Raw | ConvertFrom-Json
$remote   = '/public_html/admin'

Add-Type -AssemblyName System.Web
$encUser = [System.Web.HttpUtility]::UrlEncode($cred.username)
$encPass = [System.Web.HttpUtility]::UrlEncode($cred.password)

$timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir     = Join-Path $PSScriptRoot 'logs'
$logFile    = Join-Path $logDir "slider-vendor-$timestamp.log"
$scriptFile = Join-Path $logDir "slider-vendor-$timestamp.txt"

$files = @(
    'database/migrations/2026_06_24_000001_add_vendor_id_to_sliders.php',
    'app/Models/Slider.php',
    'app/Http/Controllers/Api/SliderController.php'
)

$lines = @(
    'option batch abort'
    'option confirm off'
    'option transfer binary'
    "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"
)
foreach ($f in $files) {
    $local      = (Join-Path $repoRoot "server-admin/$f").Replace('/', '\')
    $remoteFile = "$remote/$f"
    $lines += "put -nopermissions -nopreservetime ""$local"" ""$remoteFile"""
}
$lines += @('close','exit')

Set-Content -Path $scriptFile -Value $lines -Encoding UTF8
& $winscp "/script=$scriptFile" "/log=$logFile" "/loglevel=1" "/ini=nul"
Write-Host "WinSCP exit: $LASTEXITCODE"
