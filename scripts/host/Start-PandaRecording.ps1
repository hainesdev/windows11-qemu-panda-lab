[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$Name,
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$Snapshot
)

$monitor = Join-Path $PSScriptRoot 'Invoke-PandaMonitor.ps1'
if ($Snapshot) { & $monitor "loadvm $Snapshot" -TimeoutSeconds 60 }
& $monitor "begin_record /work/recordings/$Name" -TimeoutSeconds 60
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
