#
# One-shot: delete a throwaway account created while verifying an API on
# production, plus everything it created. Uploads a token-protected runner,
# calls it with the id AND phone (both must match a single row), then removes
# the runner from the server.
#
#   deploy\cleanup-test-user.ps1 -UserId 34830 -Phone 0599000771
#
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][int]$UserId,
    [Parameter(Mandatory = $true)][string]$Phone,
    # Posts whose cached likes_count this account bumped, to walk back by one.
    [string]$Posts = '',
    # Sweep leftovers when the account itself was already deleted.
    [switch]$OrphansOnly
)
$ErrorActionPreference = 'Stop'

$winscpCandidates = @(
    "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com",
    "C:\Program Files\WinSCP\WinSCP.com",
    "C:\Program Files (x86)\WinSCP\WinSCP.com"
)
$winscp = $winscpCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $winscp) { throw "WinSCP.com not found" }

$cred = Get-Content (Join-Path $PSScriptRoot '.ftp-credentials.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$encUser = [System.Web.HttpUtility]::UrlEncode($cred.username)
$encPass = [System.Web.HttpUtility]::UrlEncode($cred.password)

$token = [guid]::NewGuid().ToString('N')
$tpl   = Get-Content (Join-Path $PSScriptRoot '_cleanup_test_user.php.tpl') -Raw
$runnerLocal = Join-Path $PSScriptRoot "_cleanup_$token.php"
($tpl -replace '__TOKEN__', $token) | Set-Content -Path $runnerLocal -Encoding ASCII

$runnerRemoteName = "_cleanup_$token.php"
$remote = "/public_html/admin/public/$runnerRemoteName"

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir    = Join-Path $PSScriptRoot 'logs'
$script    = Join-Path $logDir "cleanup-$timestamp.txt"
$log       = Join-Path $logDir "cleanup-$timestamp.log"

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

$url = "https://afrahna.co/admin/$runnerRemoteName`?t=$token&user=$UserId&phone=$Phone&posts=$Posts&orphans=$(if ($OrphansOnly) { '1' } else { '0' })"
Write-Host "GET (cleanup runner for user $UserId)"
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

# The runner does not self-delete (it may need a second look), so remove it here.
$cleanupScript = Join-Path $logDir "cleanup-rm-$timestamp.txt"
Set-Content -Path $cleanupScript -Encoding UTF8 -Value @(
    'option batch continue'
    'option confirm off'
    "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"
    "rm ""$remote"""
    'close'
    'exit'
)
& $winscp "/script=$cleanupScript" "/loglevel=0" "/ini=nul" | Out-Null

Remove-Item $runnerLocal -ErrorAction SilentlyContinue
Write-Host "runner removed from the server"
