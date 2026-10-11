#
# Publishes the public website (afrahna-web/out) to the afrahna.ps host.
#
#   deploy\deploy-website.ps1 -DryRun          # show what would change
#   deploy\deploy-website.ps1                  # upload
#   deploy\deploy-website.ps1 -Server 1.2.3.4  # connect by IP, skipping DNS
#   deploy\deploy-website.ps1 -Mirror          # ALSO delete remote extras
#
# Upload-only by default. `-Mirror` turns on remote deletions, which is right
# for a folder this script owns and wrong for a web root that may still hold
# somebody else's files — so it is a decision, not a default.
#
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Mirror,
    [string]$Server,
    # Which host to publish to. The two differ in more than a hostname:
    #  ps — a domain-scoped FTP account, chrooted to its own document root, so
    #       '/' there IS the web root.
    #  co — the full cPanel login, whose root also holds admin/, dashboard/,
    #       i/ and v/, so the site goes into /public_html alongside them.
    [ValidateSet('ps', 'co')]
    [string]$Site = 'ps',
    [string]$Remote
)
$ErrorActionPreference = 'Stop'

$winscpCandidates = @(
    "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com",
    "C:\Program Files\WinSCP\WinSCP.com",
    "C:\Program Files (x86)\WinSCP\WinSCP.com"
)
$winscp = $winscpCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $winscp) { throw "WinSCP.com not found" }

$repoRoot  = Split-Path -Parent $PSScriptRoot
$localPath = Join-Path $repoRoot 'afrahna-web\out'
if (-not (Test-Path (Join-Path $localPath 'index.html'))) {
    throw "No export found at $localPath. Run: npm run export (inside afrahna-web). A plain next build does NOT produce out/."
}

# Apache config is not part of the Next export, so it is staged into out/ here.
# Two files, deliberately: the root one is inherited by everything beside the
# site (on afrahna.co that means admin/, dashboard/, i/ and v/), so it carries
# only site-wide-safe rules; the aggressive immutable caching is confined to
# _next/, whose filenames are content-hashed.
$rootHta = Join-Path $PSScriptRoot 'website.htaccess'
$nextHta = Join-Path $PSScriptRoot 'website-next.htaccess'
if (Test-Path $rootHta) {
    Copy-Item $rootHta (Join-Path $localPath '.htaccess') -Force
    Write-Host "staged .htaccess"
}
if ((Test-Path $nextHta) -and (Test-Path (Join-Path $localPath '_next'))) {
    Copy-Item $nextHta (Join-Path $localPath '_next\.htaccess') -Force
    Write-Host "staged _next/.htaccess"
}

$credFile = if ($Site -eq 'co') { '.ftp-credentials.json' } else { '.ftp-credentials-ps.json' }
$cred = Get-Content (Join-Path $PSScriptRoot $credFile) -Raw | ConvertFrom-Json
$hostName = if ($Server) { $Server } else { $cred.host }
if (-not $Remote) { $Remote = if ($Site -eq 'co') { '/public_html' } else { '/' } }

Add-Type -AssemblyName System.Web
$encUser = [System.Web.HttpUtility]::UrlEncode($cred.username)
$encPass = [System.Web.HttpUtility]::UrlEncode($cred.password)

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir    = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$script    = Join-Path $logDir "website-$timestamp.txt"
$log       = Join-Path $logDir "website-$timestamp.log"

# -delete is a PRESENCE flag in WinSCP: "-delete=off" does not turn deletion
# off, it turns it ON. That mistake deleted 225 files out of the live Laravel
# app's vendor/ directory and took the API down. The flag is now either the
# bare switch or absent entirely.
$deleteFlag = if ($Mirror) { '-delete' } else { '' }
$mirrorFlag = if ($Mirror) { '-mirror' } else { '' }
$preview    = if ($DryRun) { '-preview' } else { '' }

$lines = @(
    'option batch abort'
    'option confirm off'
    'option transfer binary'
    'option reconnecttime 30'
    "open ftpes://${encUser}:${encPass}@${hostName}:$($cred.port) -explicit -certificate=*"
    "synchronize remote $preview $mirrorFlag $deleteFlag -criteria=time -nopermissions -nopreservetime ""$localPath"" ""$Remote"""
    'close'
    'exit'
)
Set-Content -Path $script -Value $lines -Encoding UTF8

Write-Host "Target: $Site"
Write-Host "Local : $localPath"
Write-Host "Remote: ftpes://${hostName}:$($cred.port)$Remote"
Write-Host ("Mode  : " + $(if ($DryRun) { 'DRY RUN' } elseif ($Mirror) { 'UPLOAD + DELETE REMOTE EXTRAS' } else { 'UPLOAD ONLY (nothing deleted)' }))

& $winscp "/script=$script" "/log=$log" "/loglevel=1" "/ini=nul"
$code = $LASTEXITCODE
Write-Host "WinSCP exit code: $code"
if ($code -ne 0) { Write-Host "Log: $log" }
exit $code
