#
# A small API deploy, in three phases so the live files can be diffed before
# anything is overwritten:
#   -Phase get      download the live copies of the files about to change
#   -Phase put      upload the changed and added files (no vendor sync)
#   -Phase migrate  through a token runner: prove the classes load, apply only
#                   the named migration, check its columns, clear caches, and
#                   delete the runner
#
# Example:
#   .\deploy-api-batch.ps1 -Phase get -Changed app/Models/Vendor.php
#   .\deploy-api-batch.ps1 -Phase put -Changed ... -Added database/migrations/x.php
#   .\deploy-api-batch.ps1 -Phase migrate -Migration database/migrations/x.php `
#       -Classes 'App\Models\Vendor' -Columns vendors.allow_reels
#
[CmdletBinding()]
param(
    [ValidateSet('get', 'put', 'migrate')]
    [string]$Phase = 'get',
    [string[]]$Changed = @(),
    [string[]]$Added = @(),
    [string]$Migration = '',
    [string[]]$Classes = @(),
    [string[]]$Columns = @()
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

function Invoke-WinScp([string[]]$lines, [string]$name) {
    $scriptFile = Join-Path $logDir "$name-$timestamp.txt"
    $logFile    = Join-Path $logDir "$name-$timestamp.log"
    Set-Content -Path $scriptFile -Value $lines -Encoding UTF8
    & $winscp "/script=$scriptFile" "/log=$logFile" "/loglevel=1" "/ini=nul"
    if ($LASTEXITCODE -ne 0) { throw "WinSCP failed ($name): $LASTEXITCODE" }
}

switch ($Phase) {
    'get' {
        if (-not $Changed) { throw 'get: -Changed is empty' }
        $liveDir = Join-Path $logDir "live-$timestamp"
        New-Item -ItemType Directory -Path $liveDir | Out-Null
        $lines = @('option batch abort', 'option confirm off', 'option transfer binary', $open)
        foreach ($f in $Changed) {
            $local = (Join-Path $liveDir $f).Replace('/', '\')
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $local) | Out-Null
            $lines += "get ""$remote/$f"" ""$local"""
        }
        $lines += @('close', 'exit')
        Invoke-WinScp $lines 'batch-get'
        Write-Host "LIVE_DIR=$liveDir"
    }
    'put' {
        $all = @($Changed) + @($Added)
        if (-not $all) { throw 'put: nothing to upload' }
        $lines = @('option batch abort', 'option confirm off', 'option transfer binary', $open)
        foreach ($f in $all) {
            $local = (Join-Path $repoRoot "server-admin/$f").Replace('/', '\')
            if (-not (Test-Path $local)) { throw "missing local file: $local" }
            $lines += "put -nopermissions -nopreservetime ""$local"" ""$remote/$f"""
        }
        $lines += @('close', 'exit')
        Invoke-WinScp $lines 'batch-put'
        Write-Host "uploaded $($all.Count) files"
    }
    'migrate' {
        $token = [guid]::NewGuid().ToString('N')
        $tpl   = Get-Content (Join-Path $PSScriptRoot '_run_api_batch.php.tpl') -Raw
        $phpList = { param($items) '[' + (($items | ForEach-Object { "'" + ($_ -replace "'", "\'") + "'" }) -join ', ') + ']' }
        $body = $tpl -replace '__TOKEN__', $token
        $body = $body -replace '__MIGRATION__', $Migration
        $body = $body -replace '__CLASSES__', (& $phpList $Classes)
        $body = $body -replace '__COLUMNS__', (& $phpList $Columns)
        $runnerLocal = Join-Path $PSScriptRoot "_run_api_batch_$token.php"
        [System.IO.File]::WriteAllText($runnerLocal, $body, (New-Object System.Text.UTF8Encoding $false))
        $runnerRemote = "$remote/public/_run_api_batch_$token.php"
        try {
            Invoke-WinScp @(
                'option batch abort', 'option confirm off', 'option transfer binary', $open,
                "put -nopermissions -nopreservetime ""$runnerLocal"" ""$runnerRemote""",
                'close', 'exit'
            ) 'batch-runner'

            $url = "https://afrahna.co/admin/_run_api_batch_$token.php?t=$token"
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
            $cleanup = Join-Path $logDir "batch-cleanup-$timestamp.txt"
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
