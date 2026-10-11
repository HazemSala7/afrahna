# Read-only: connect and list, so we know the remote layout before writing.
#
#   deploy\_list-ps.ps1                    # via the hostname in the cred file
#   deploy\_list-ps.ps1 -Server 1.2.3.4    # via an IP, skipping DNS
[CmdletBinding()]
param([string]$Server)
$ErrorActionPreference = 'Stop'

$winscp = "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
if (-not (Test-Path $winscp)) { $winscp = "C:\Program Files (x86)\WinSCP\WinSCP.com" }

$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials-ps.json') -Raw | ConvertFrom-Json
$hostName = if ($Server) { $Server } else { $cred.host }

Add-Type -AssemblyName System.Web
$u = [System.Web.HttpUtility]::UrlEncode($cred.username)
$p = [System.Web.HttpUtility]::UrlEncode($cred.password)

$script = Join-Path $env:TEMP 'afrahna-ps-list.txt'
Set-Content -Path $script -Encoding UTF8 -Value @(
  'option batch abort'
  'option confirm off'
  "open ftpes://${u}:${p}@${hostName}:$($cred.port) -explicit -certificate=*"
  'pwd'
  'ls'
  'close'
  'exit'
)

Write-Host "Connecting to $hostName as $($cred.username) ..."
& $winscp "/script=$script" "/loglevel=0" "/ini=nul"
exit $LASTEXITCODE
