# 1. Confirm the file Laravel says is missing is actually present.
# 2. Remove the partial website upload from the web root — those directories
#    are mine, from the deploy that failed, and they are taking space the
#    application needs to run.
$ErrorActionPreference = 'Continue'
$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
if (-not (Test-Path $winscp)) { $winscp = "C:\Program Files (x86)\WinSCP\WinSCP.com" }

$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)

# Only directories this deploy created. Nothing pre-existing is listed:
# admin/, dashboard/, i/, v/, cgi-bin/, .well-known/ are all left alone.
$mine = @('404', '_next', 'about', 'advertise', 'app', 'categories', 'category',
          'city', 'contact', 'invitations', 'offers', 'planning', 'points',
          'privacy', 'product', 'products', 'reels', 'search', 'stories',
          'vendor', 'vendors')

$lines = @(
    'option batch continue'
    'option confirm off'
    "open ftpes://${u}:${p}@$($cred.host):$($cred.port) -explicit -certificate=*"
    'echo === does helpers.php exist? ==='
    'ls /public_html/admin/vendor/mockery/mockery/library'
    'echo === removing the partial website upload ==='
)
foreach ($d in $mine) { $lines += "rm /public_html/$d" }
$lines += @('rm /public_html/index.html', 'rm /public_html/sitemap.xml',
            'rm /public_html/robots.txt', 'rm /public_html/og.jpg',
            'rm /public_html/logo.png', 'rm /public_html/favicon.png',
            'rm /public_html/index.txt')
$lines += @('close', 'exit')

$script = Join-Path $env:TEMP 'afrahna-verify-clean.txt'
Set-Content -Path $script -Value $lines -Encoding UTF8
& $winscp "/script=$script" "/loglevel=0" "/ini=nul"
