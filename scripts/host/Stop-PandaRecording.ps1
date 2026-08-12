[CmdletBinding()]
param()

& (Join-Path $PSScriptRoot 'Invoke-PandaMonitor.ps1') 'end_record' -TimeoutSeconds 60
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
