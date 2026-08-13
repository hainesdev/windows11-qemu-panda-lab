[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$Name,
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$Snapshot
)

$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot 'Get-LabConfig.ps1')
$monitor = Join-Path $PSScriptRoot 'Invoke-PandaMonitor.ps1'
$statePath = Join-Path $config.WorkRoot 'active-recording.json'
$recordingBase = Join-Path (Join-Path $config.WorkRoot 'recordings') $Name

if (Test-Path -LiteralPath $statePath) {
    throw "An active or unfinalized recording marker exists: $statePath"
}
foreach ($artifact in "$recordingBase-rr-snp", "$recordingBase-rr-nondet.log") {
    if (Test-Path -LiteralPath $artifact) {
        throw "Refusing to overwrite an existing recording artifact: $artifact"
    }
}

if ($Snapshot) {
    $snapshots = & $monitor 'info snapshots' -TimeoutSeconds 30
    if ($snapshots -notmatch "(?m)\b$([regex]::Escape($Snapshot))\b") {
        throw "Snapshot does not exist: $Snapshot"
    }
    & $monitor "loadvm $Snapshot" -TimeoutSeconds 120 | Out-Host
}

& $monitor "begin_record /work/recordings/$Name" -TimeoutSeconds 120 | Out-Host
[ordered]@{
    Name = $Name
    Snapshot = $Snapshot
    StartedAt = (Get-Date).ToString('o')
    RecordingBase = $recordingBase
} | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding utf8

Write-Host "Recording started: $Name"
Write-Host 'Finalize it with: .\scripts\host\Stop-PandaRecording.ps1'
