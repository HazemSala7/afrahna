#
# Sync `afrahna-admin-panel/out/` -> `/public_html/dashboard/`
# Static export, so it's safe to mirror with deletes (no user data lives here).
#
[CmdletBinding()]
param(
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

$winscpCandidates = @(
    "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com",
    "C:\Program Files\WinSCP\WinSCP.com",
    "C:\Program Files (x86)\WinSCP\WinSCP.com"
)
$winscp = $winscpCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $winscp) { throw "WinSCP.com not found" }

$repoRoot = Split-Path -Parent $PSScriptRoot
$localPath = (Join-Path $repoRoot 'afrahna-admin-panel\out')
if (-not (Test-Path $localPath)) { throw "Build output missing: $localPath. Run `npm run build` first." }

$credPath = Join-Path $PSScriptRoot '.ftp-credentials.json'
$cred     = Get-Content $credPath -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$encUser  = [System.Web.HttpUtility]::UrlEncode($cred.username)
$encPass  = [System.Web.HttpUtility]::UrlEncode($cred.password)
$remote   = '/public_html/dashboard'

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir    = Join-Path $PSScriptRoot 'logs'
$script    = Join-Path $logDir "dashboard-$timestamp.txt"
$log       = Join-Path $logDir "dashboard-$timestamp.log"

$syncMode = if ($DryRun) { 'synchronize remote -preview' } else { 'synchronize remote' }

$lines = @(
    'option batch abort'
    'option confirm off'
    'option transfer binary'
    'option reconnecttime 30'
    "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"
    'option batch continue'
    "mkdir $remote"
    'option batch abort'
    "$syncMode -mirror -delete=on -criteria=time -nopermissions -nopreservetime ""$localPath"" ""$remote"""
    'close'
    'exit'
)
Set-Content -Path $script -Value $lines -Encoding UTF8

Write-Host "Local : $localPath"
Write-Host "Remote: ftpes://$($cred.host):$($cred.port)$remote"
Write-Host ("Mode  : " + ($(if ($DryRun) { 'DRY RUN' } else { 'LIVE UPLOAD (with remote deletes inside /dashboard only)' })))

& $winscp "/script=$script" "/log=$log" "/loglevel=1" "/ini=nul"
exit $LASTEXITCODE
