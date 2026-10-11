param([Parameter(Mandatory=$true)][string]$LocalRel, [Parameter(Mandatory=$true)][string]$Remote)
$ErrorActionPreference = 'Stop'
$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)
$repoRoot = Split-Path -Parent $PSScriptRoot
$local = Join-Path $repoRoot $LocalRel
if (-not (Test-Path $local)) { throw "missing local file: $local" }
$script = Join-Path $env:TEMP 'afrahna-restore-file.txt'
Set-Content -Path $script -Encoding UTF8 -Value @(
  'option batch abort'
  'option confirm off'
  'option transfer binary'
  "open ftpes://${u}:${p}@$($cred.host):$($cred.port) -explicit -certificate=*"
  "put -nopermissions ""$local"" ""$Remote"""
  'close'
  'exit'
)
& $winscp "/script=$script" "/loglevel=0" "/ini=nul"
