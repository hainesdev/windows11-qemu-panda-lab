[CmdletBinding()]
param(
    [ValidateRange(10, 600)]
    [int]$FinalizeTimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot 'Get-LabConfig.ps1')
$statePath = Join-Path $config.WorkRoot 'active-recording.json'
if (-not (Test-Path -LiteralPath $statePath)) {
    throw "No active recording marker was found: $statePath"
}

$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
& (Join-Path $PSScriptRoot 'Invoke-PandaMonitor.ps1') 'end_record' `
    -TimeoutSeconds $FinalizeTimeoutSeconds | Out-Host

$snapshotFile = "$($state.RecordingBase)-rr-snp"
$nondeterminismFile = "$($state.RecordingBase)-rr-nondet.log"
$deadline = (Get-Date).AddSeconds($FinalizeTimeoutSeconds)
do {
    $snapshotReady = (Test-Path -LiteralPath $snapshotFile) -and
        (Get-Item -LiteralPath $snapshotFile).Length -gt 0
    $nondeterminismReady = (Test-Path -LiteralPath $nondeterminismFile) -and
        (Get-Item -LiteralPath $nondeterminismFile).Length -gt 0
    if ($snapshotReady -and $nondeterminismReady) { break }
    Start-Sleep -Seconds 1
} while ((Get-Date) -lt $deadline)

if (-not ($snapshotReady -and $nondeterminismReady)) {
    throw "Recording did not finalize into two nonempty artifacts. Marker retained at: $statePath"
}

$metadataPath = "$($state.RecordingBase)-metadata.json"
[ordered]@{
    Name = $state.Name
    Snapshot = $state.Snapshot
    StartedAt = $state.StartedAt
    EndedAt = (Get-Date).ToString('o')
    SnapshotFile = $snapshotFile
    SnapshotBytes = (Get-Item -LiteralPath $snapshotFile).Length
    NondeterminismFile = $nondeterminismFile
    NondeterminismBytes = (Get-Item -LiteralPath $nondeterminismFile).Length
} | ConvertTo-Json | Set-Content -LiteralPath $metadataPath -Encoding utf8

Remove-Item -LiteralPath $statePath -Force
Write-Host "Recording finalized: $($state.Name)"
Write-Host "Metadata: $metadataPath"
