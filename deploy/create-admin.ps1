#
# One-shot: create/update the admin user (phone 123123123 / 123456) on production.
# Uploads a token-protected runner to public/, calls it, then deletes it.
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

# Build runner with random token
$token = [guid]::NewGuid().ToString('N')
$tpl   = Get-Content (Join-Path $PSScriptRoot '_create_admin.php.tpl') -Raw
$runnerLocal = Join-Path $PSScriptRoot "_create_admin_$token.php"
($tpl -replace '__TOKEN__', $token) | Set-Content -Path $runnerLocal -Encoding ASCII

$runnerRemoteName = "_create_admin_$token.php"
$remote = "/public_html/admin/public/$runnerRemoteName"

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir    = Join-Path $PSScriptRoot 'logs'
$script    = Join-Path $logDir "create-admin-$timestamp.txt"
$log       = Join-Path $logDir "create-admin-$timestamp.log"

$lines = @(
    'option batch abort'
    'option confirm off'
    'option transfer binary'
    "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"
    "put -nopermissions -nopreservetime ""$runnerLocal"" ""$remote"""
    'close'
    'exit'
)
Set-Content -Path $script -Value $lines -Encoding UTF8
& $winscp "/script=$script" "/log=$log" "/loglevel=1" "/ini=nul"
if ($LASTEXITCODE -ne 0) {
    Remove-Item $runnerLocal -ErrorAction SilentlyContinue
    throw "FTP upload failed: $LASTEXITCODE"
}

$url = "https://afrahna.co/admin/$runnerRemoteName`?t=$token"
Write-Host "GET $url"
try {
    $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 120
    Write-Host $resp.Content
} catch {
    Write-Warning "HTTP call failed: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Host $sr.ReadToEnd()
    }
}

# Best-effort delete on server in case the script didn't self-delete
$cleanupScript = Join-Path $logDir "create-admin-cleanup-$timestamp.txt"
$cleanupLines = @(
    'option batch continue'
    'option confirm off'
    "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"
    "rm ""$remote"""
    'close'
    'exit'
)
Set-Content -Path $cleanupScript -Value $cleanupLines -Encoding UTF8
& $winscp "/script=$cleanupScript" "/loglevel=0" "/ini=nul" | Out-Null

Remove-Item $runnerLocal -ErrorAction SilentlyContinue
