#
# Shop-page facts deploy (2026-10-11): working_hours / delivery_note columns,
# photos/videos counts on the shop page, and the points/invitees endpoint.
#
# Three phases, run in order so the live files can be diffed before anything
# is overwritten:
#   -Phase get      download the live copies of the files about to change
#   -Phase put      upload the changed files (no vendor sync)
#   -Phase migrate  run only the new migration through a token runner, prove
#                   the changed classes load, then delete the runner
#
[CmdletBinding()]
param(
    [ValidateSet('get', 'put', 'migrate')]
    [string]$Phase = 'get'
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
$remote   = '/public_html/admin'

Add-Type -AssemblyName System.Web
$encUser = [System.Web.HttpUtility]::UrlEncode($cred.username)
$encPass = [System.Web.HttpUtility]::UrlEncode($cred.password)
$open    = "open ftpes://${encUser}:${encPass}@$($cred.host):$($cred.port) -explicit -certificate=*"

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir    = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

# Files that already exist on the server and are about to be replaced.
$changed = @(
    'app/Models/Vendor.php',
    'app/Http/Controllers/Api/VendorController.php',
    'app/Http/Controllers/Api/PointController.php',
    'routes/api.php'
)
# New on the server.
$added = @(
    'database/migrations/2026_10_10_000001_add_profile_facts_to_vendors.php'
)

function Invoke-WinScp([string[]]$lines, [string]$name) {
    $scriptFile = Join-Path $logDir "$name-$timestamp.txt"
    $logFile    = Join-Path $logDir "$name-$timestamp.log"
    Set-Content -Path $scriptFile -Value $lines -Encoding UTF8
    & $winscp "/script=$scriptFile" "/log=$logFile" "/loglevel=1" "/ini=nul"
    if ($LASTEXITCODE -ne 0) { throw "WinSCP failed ($name): $LASTEXITCODE" }
}

switch ($Phase) {
    'get' {
        $liveDir = Join-Path $logDir "live-$timestamp"
        New-Item -ItemType Directory -Path $liveDir | Out-Null
        $lines = @('option batch abort', 'option confirm off', 'option transfer binary', $open)
        foreach ($f in $changed) {
            $local = (Join-Path $liveDir $f).Replace('/', '\')
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $local) | Out-Null
            $lines += "get ""$remote/$f"" ""$local"""
        }
        $lines += @('close', 'exit')
        Invoke-WinScp $lines 'shopfacts-get'
        Write-Host "LIVE_DIR=$liveDir"
    }
    'put' {
        $lines = @('option batch abort', 'option confirm off', 'option transfer binary', $open)
        foreach ($f in ($changed + $added)) {
            $local = (Join-Path $repoRoot "server-admin/$f").Replace('/', '\')
            if (-not (Test-Path $local)) { throw "missing local file: $local" }
            $lines += "put -nopermissions -nopreservetime ""$local"" ""$remote/$f"""
        }
        $lines += @('close', 'exit')
        Invoke-WinScp $lines 'shopfacts-put'
        Write-Host "uploaded $(($changed + $added).Count) files"
    }
    'migrate' {
        $token = [guid]::NewGuid().ToString('N')
        $tpl   = Get-Content (Join-Path $PSScriptRoot '_run_shop_facts.php.tpl') -Raw
        $runnerLocal = Join-Path $PSScriptRoot "_run_shop_facts_$token.php"
        ($tpl -replace '__TOKEN__', $token) | Set-Content -Path $runnerLocal -Encoding ASCII
        $runnerRemote = "$remote/public/_run_shop_facts_$token.php"
        try {
            Invoke-WinScp @(
                'option batch abort', 'option confirm off', 'option transfer binary', $open,
                "put -nopermissions -nopreservetime ""$runnerLocal"" ""$runnerRemote""",
                'close', 'exit'
            ) 'shopfacts-runner'

            $url = "https://afrahna.co/admin/_run_shop_facts_$token.php?t=$token"
            try {
                $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 180
                Write-Host $resp.Content
            } catch {
                Write-Warning "HTTP call failed: $($_.Exception.Message)"
                if ($_.Exception.Response) {
                    $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                    Write-Host $sr.ReadToEnd()
                }
            }
        } finally {
            # The runner must not outlive this script, whatever happened above.
            $cleanup = Join-Path $logDir "shopfacts-cleanup-$timestamp.txt"
            Set-Content -Path $cleanup -Value @(
                'option batch continue', 'option confirm off', $open,
                "rm ""$runnerRemote""", 'close', 'exit'
            ) -Encoding UTF8
            & $winscp "/script=$cleanup" "/loglevel=0" "/ini=nul" | Out-Null
            Remove-Item $runnerLocal -ErrorAction SilentlyContinue
            Write-Host "runner removed"
        }
    }
}
