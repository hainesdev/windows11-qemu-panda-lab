[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$Name = 'root'
)

& (Join-Path $PSScriptRoot 'Invoke-PandaMonitor.ps1') "savevm $Name" -TimeoutSeconds 60
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
