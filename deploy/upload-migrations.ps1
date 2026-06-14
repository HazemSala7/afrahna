#
# Upload the pending migration(s) then run them.
#
[CmdletBinding()]
param(
    [string[]]$Files = @(
        'database/migrations/2026_05_25_000001_add_permissions_to_users.php',
        'database/migrations/2026_05_24_000002_extend_users_for_roles.php',
        'database/migrations/2026_05_20_000001_update_users_table.php'
    )
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
$credPath = Join-Path $PSScriptRoot '.ftp-credentials.json'
$cred     = Get-Content $credPath -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
$encUser  = [System.Web.HttpUtility]::UrlEncode($cred.username)
$encPass  = [System.Web.HttpUtility]::UrlEncode($cred.password)
$remote   = '/public_html/admin'

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir    = Join-Path $PSScriptRoot 'logs'
$script    = Join-Path $logDir "migrations-$timestamp.txt"
$log       = Join-Path $logDir "migrations-$timestamp.log"

$lines = @(
    'option batch abort'
    'option confirm off'
    'option transfer binary'
    "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"
)
foreach ($f in $Files) {
    $local = (Join-Path $repoRoot "server-admin/$f").Replace('/', '\')
    if (-not (Test-Path $local)) { Write-Warning "skip missing: $local"; continue }
    $lines += "put -nopermissions -nopreservetime ""$local"" ""$remote/$f"""
}
$lines += @('close','exit')
Set-Content -Path $script -Value $lines -Encoding UTF8
& $winscp "/script=$script" "/log=$log" "/loglevel=1" "/ini=nul"
exit $LASTEXITCODE
