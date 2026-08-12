[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$Name
)

$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot 'Get-LabConfig.ps1')
$running = docker ps --filter "name=^/$($config.Container)$" --format '{{.Names}}'
if ($running -eq $config.Container) { throw 'Stop the live PANDA VM before replay analysis.' }

$recordingBase = Join-Path (Join-Path $config.WorkRoot 'recordings') $Name
foreach ($recordingFile in "$recordingBase-rr-snp", "$recordingBase-rr-nondet.log") {
    if (-not (Test-Path -LiteralPath $recordingFile) -or (Get-Item -LiteralPath $recordingFile).Length -eq 0) {
        throw "Recording file is missing or empty: $recordingFile"
    }
}

$workMount = "$($config.WorkRoot):/work"
& docker run --rm --volume $workMount $config.Image /opt/panda-tools/run-replay.sh $Name
if ($LASTEXITCODE -ne 0) { throw "Replay analysis failed for: $Name" }

$coverage = Join-Path $config.WorkRoot "analyses\$Name-coverage.csv"
if (-not (Test-Path -LiteralPath $coverage) -or (Get-Item -LiteralPath $coverage).Length -eq 0) {
    throw "Replay completed without a nonempty coverage report: $coverage"
}
Write-Host "Coverage written to $coverage"
