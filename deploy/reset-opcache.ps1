#
# Upload _opcache_reset.php to public_html/admin/public, hit it via HTTPS, then it self-destructs.
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

$credPath = Join-Path $PSScriptRoot '.ftp-credentials.json'
$cred     = Get-Content $credPath -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$encUser = [System.Web.HttpUtility]::UrlEncode($cred.username)
$encPass = [System.Web.HttpUtility]::UrlEncode($cred.password)

$local  = Join-Path $PSScriptRoot '_opcache_reset.php'
$remote = '/public_html/admin/public/_opcache_reset.php'

$timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir     = Join-Path $PSScriptRoot 'logs'
$scriptFile = Join-Path $logDir "opcache-$timestamp.txt"
$logFile    = Join-Path $logDir "opcache-$timestamp.log"

$lines = @(
    'option batch abort'
    'option confirm off'
    'option transfer binary'
    "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"
    "put -nopermissions -nopreservetime ""$local"" ""$remote"""
    'close'
    'exit'
)
Set-Content -Path $scriptFile -Value $lines -Encoding UTF8
& $winscp "/script=$scriptFile" "/log=$logFile" "/loglevel=1" "/ini=nul"
if ($LASTEXITCODE -ne 0) { throw "FTP upload failed: $LASTEXITCODE" }

$url = "https://afrahna.co/admin/_opcache_reset.php"
Write-Host "GET $url"
try {
    $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
    Write-Host $resp.Content
} catch {
    Write-Warning "HTTP call failed: $($_.Exception.Message)"
}
