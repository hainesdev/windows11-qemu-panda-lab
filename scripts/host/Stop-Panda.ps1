[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot 'Get-LabConfig.ps1')
$recordingMarker = Join-Path $config.WorkRoot 'active-recording.json'
if ((Test-Path -LiteralPath $recordingMarker) -and -not $Force) {
    throw "A recording may still be active. Run Stop-PandaRecording.ps1 first, or use -Force only for recovery: $recordingMarker"
}
$running = docker ps --filter "name=^/$($config.Container)$" --format '{{.Names}}'
if ($running -ne $config.Container) {
    Write-Host 'PANDA is not running.'
    exit 0
}

try {
    & (Join-Path $PSScriptRoot 'Invoke-PandaMonitor.ps1') 'system_powerdown' | Out-Host
} catch {
    Write-Warning "Could not request ACPI shutdown: $($_.Exception.Message)"
}

$deadline = (Get-Date).AddSeconds(60)
do {
    Start-Sleep -Seconds 1
    $running = docker ps --filter "name=^/$($config.Container)$" --format '{{.Names}}'
} while ($running -eq $config.Container -and (Get-Date) -lt $deadline)

if ($running -eq $config.Container) {
    Write-Warning 'Guest did not shut down within 60 seconds; asking Docker to stop it.'
    docker stop --time 20 $config.Container | Out-Null
}
Write-Host 'PANDA stopped.'
