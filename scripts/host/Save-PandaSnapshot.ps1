[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$Name = 'root'
)

$monitor = Join-Path $PSScriptRoot 'Invoke-PandaMonitor.ps1'
& $monitor "savevm $Name" -TimeoutSeconds 120 | Out-Host
$snapshots = & $monitor 'info snapshots' -TimeoutSeconds 30
if ($snapshots -notmatch "(?m)\b$([regex]::Escape($Name))\b") {
    throw "QEMU did not list the requested snapshot after savevm: $Name"
}
$snapshots
