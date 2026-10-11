#
# One-shot: create (or refresh) the test shop-owner account on production.
# Generates a fresh password each run, uploads a token-protected runner to
# public/, calls it, deletes it, and prints the credentials once — they are
# written nowhere else.
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

# A password that can be typed on a phone: eight letters and digits, no
# look-alikes.
$alphabet = 'abcdefghjkmnpqrstuvwxyz23456789'.ToCharArray()
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 8
$rng.GetBytes($bytes)
$password = -join ($bytes | ForEach-Object { $alphabet[$_ % $alphabet.Length] })

$token = [guid]::NewGuid().ToString('N')
$tpl   = Get-Content (Join-Path $PSScriptRoot '_create_test_shop.php.tpl') -Raw -Encoding UTF8
$runnerLocal = Join-Path $PSScriptRoot "_create_test_shop_$token.php"
$body = ($tpl -replace '__TOKEN__', $token) -replace '__PASSWORD__', $password
[System.IO.File]::WriteAllText($runnerLocal, $body, (New-Object System.Text.UTF8Encoding $false))

$runnerRemoteName = "_create_test_shop_$token.php"
$remote = "/public_html/admin/public/$runnerRemoteName"

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir    = Join-Path $PSScriptRoot 'logs'
$script    = Join-Path $logDir "test-shop-$timestamp.txt"
$log       = Join-Path $logDir "test-shop-$timestamp.log"

try {
    Set-Content -Path $script -Encoding UTF8 -Value @(
        'option batch abort'
        'option confirm off'
        'option transfer binary'
        "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"
        "put -nopermissions -nopreservetime ""$runnerLocal"" ""$remote"""
        'close'
        'exit'
    )
    & $winscp "/script=$script" "/log=$log" "/loglevel=0" "/ini=nul" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "FTP upload failed: $LASTEXITCODE" }

    $url = "https://afrahna.co/admin/$runnerRemoteName`?t=$token"
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 120
        Write-Host $resp.Content
        if ($resp.Content -match 'OK') {
            Write-Host "LOGIN phone=0599990001 password=$password"
        }
    } catch {
        Write-Warning "HTTP call failed: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            Write-Host $sr.ReadToEnd()
        }
    }
} finally {
    $cleanup = Join-Path $logDir "test-shop-cleanup-$timestamp.txt"
    Set-Content -Path $cleanup -Encoding UTF8 -Value @(
        'option batch continue'
        'option confirm off'
        "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"
        "rm ""$remote"""
        'close'
        'exit'
    )
    & $winscp "/script=$cleanup" "/loglevel=0" "/ini=nul" | Out-Null
    Remove-Item $runnerLocal -ErrorAction SilentlyContinue
    Write-Host "runner removed"
}
