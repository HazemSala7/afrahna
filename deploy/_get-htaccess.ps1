[CmdletBinding()]
param([string]$Server)
$ErrorActionPreference = 'Stop'
$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials-ps.json') -Raw | ConvertFrom-Json
$hostName = if ($Server) { $Server } else { $cred.host }
Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)
$dest = Join-Path $PSScriptRoot 'logs\remote-htaccess.txt'
$script = Join-Path $env:TEMP 'afrahna-ps-get.txt'
Set-Content -Path $script -Encoding UTF8 -Value @(
  'option batch abort'
  'option confirm off'
  "open ftpes://${u}:${p}@${hostName}:$($cred.port) -explicit -certificate=*"
  "get -nopermissions ""/.htaccess"" ""$dest"""
  'close'
  'exit'
)
& $winscp "/script=$script" "/loglevel=0" "/ini=nul" | Out-Null
if (Test-Path $dest) { Get-Content $dest -Raw }
