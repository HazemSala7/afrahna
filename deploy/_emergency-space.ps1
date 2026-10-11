# EMERGENCY: the API is returning 500 because the disk is full and Laravel
# cannot write. Removes ONLY files the framework regenerates by itself:
#   storage/logs/laravel.log        — the log; a new one is opened on demand
#   storage/framework/views/*       — compiled Blade templates
#   storage/framework/cache/data/*  — the cache store
# Nothing under uploads/ is touched: those are the shops' own pictures.
$ErrorActionPreference = 'Continue'
$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)
$base = '/public_html/admin/storage'
$script = Join-Path $env:TEMP 'afrahna-emergency.txt'
Set-Content -Path $script -Encoding UTF8 -Value @(
  'option batch continue'
  'option confirm off'
  "open ftpes://${u}:${p}@$($cred.host):$($cred.port) -explicit -certificate=*"
  "rm $base/logs/laravel.log"
  "rm $base/framework/views/*.php"
  "rm $base/framework/cache/data/*"
  'close'
  'exit'
)
& $winscp "/script=$script" "/loglevel=0" "/ini=nul"
