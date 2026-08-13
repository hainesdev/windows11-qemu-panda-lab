[CmdletBinding()]
param(
    [ValidateRange(10, 1440)]
    [int]$TimeoutMinutes = 240,
    [ValidateRange(10, 300)]
    [int]$PollSeconds = 30
)

$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot 'Get-LabConfig.ps1')
$key = Join-Path $config.WorkRoot 'ssh\panda-win11-ed25519'
$knownHosts = Join-Path $config.WorkRoot 'ssh\known_hosts'
$timingRoot = Join-Path $config.WorkRoot 'logs'
New-Item -ItemType Directory -Path $timingRoot -Force | Out-Null
$timingPath = Join-Path $timingRoot "panda-boot-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

if (-not (Test-Path -LiteralPath $key)) { throw "SSH key not found: $key" }
$running = docker ps --filter "name=^/$($config.Container)$" --format '{{.Names}}'
if ($running -ne $config.Container) { throw 'The PANDA container is not running.' }

$containerStartText = docker inspect $config.Container --format '{{.State.StartedAt}}'
$containerStart = [DateTimeOffset]::Parse($containerStartText).ToLocalTime()
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$attempts = 0
$lastProgressMessage = Get-Date
$ready = $false

Write-Host "Waiting up to $TimeoutMinutes minutes for authenticated PANDA guest SSH."
Write-Host "Container start: $($containerStart.ToString('o'))"

do {
    $attempts++
    $sshOutput = & ssh -p $config.SshPort -i $key `
        -o "UserKnownHostsFile=$knownHosts" `
        -o 'StrictHostKeyChecking=accept-new' `
        -o 'BatchMode=yes' `
        -o 'ConnectTimeout=10' `
        panda@127.0.0.1 'Write-Output PANDA_SSH_READY' 2>$null
    $ready = $LASTEXITCODE -eq 0 -and $sshOutput -contains 'PANDA_SSH_READY'
    if ($ready) { break }

    if (((Get-Date) - $lastProgressMessage).TotalMinutes -ge 5) {
        $elapsed = [Math]::Round(((Get-Date) - $containerStart.DateTime).TotalMinutes, 1)
        Write-Host "Still waiting after $elapsed minutes ($attempts SSH attempts)."
        $lastProgressMessage = Get-Date
    }
    Start-Sleep -Seconds $PollSeconds
} while ((Get-Date) -lt $deadline)

$finished = Get-Date
$result = [ordered]@{
    Container = $config.Container
    ContainerStartedAt = $containerStart.ToString('o')
    FinishedAt = $finished.ToString('o')
    ElapsedMinutes = [Math]::Round(($finished - $containerStart.DateTime).TotalMinutes, 2)
    Attempts = $attempts
    SshReady = $ready
}
$result | ConvertTo-Json | Set-Content -LiteralPath $timingPath -Encoding utf8

if (-not $ready) {
    Write-Warning "SSH did not become ready. Timing record: $timingPath"
    try { & (Join-Path $PSScriptRoot 'Invoke-PandaMonitor.ps1') 'info registers' | Out-Host } catch { Write-Warning $_.Exception.Message }
    try { & (Join-Path $PSScriptRoot 'Invoke-PandaMonitor.ps1') 'info blockstats' | Out-Host } catch { Write-Warning $_.Exception.Message }
    throw 'PANDA guest SSH readiness timed out. Continued CPU/I/O progress may justify a longer timeout.'
}

Write-Host "Authenticated SSH is ready after $($result.ElapsedMinutes) minutes."
Write-Host "Timing record: $timingPath"
