[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot 'Get-LabConfig.ps1')
. (Join-Path $PSScriptRoot 'LabPaths.ps1')

$baseDisk = Join-Path $config.VmRoot $config.BaseDisk
$prepOverlay = Resolve-LabWorkPath -Config $config -Path $config.PrepOverlay
$prepVars = Resolve-LabWorkPath -Config $config -Path $config.PrepVars

foreach ($required in $config.QemuImg, $config.HostOvmfCode, $config.HostOvmfVars, $baseDisk) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required file not found: $required"
    }
}

New-Item -ItemType Directory -Path $config.WorkRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $prepOverlay -Parent) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $prepVars -Parent) -Force | Out-Null

if (-not (Test-Path -LiteralPath $prepOverlay)) {
    & $config.QemuImg create -f qcow2 -F vdi -b $baseDisk $prepOverlay
    if ($LASTEXITCODE -ne 0) { throw 'Failed to create the QEMU preparation overlay.' }
} else {
    Write-Host "Keeping existing preparation overlay: $prepOverlay"
}

if (-not (Test-Path -LiteralPath $prepVars)) {
    Copy-Item -LiteralPath $config.HostOvmfVars -Destination $prepVars
} else {
    Write-Host "Keeping existing UEFI variable store: $prepVars"
}

& $config.QemuImg info --backing-chain $prepOverlay
if ($LASTEXITCODE -ne 0) { throw 'The preparation disk chain did not validate.' }

Write-Host 'QEMU preparation files are ready.'
Write-Host "Overlay: $prepOverlay"
Write-Host "UEFI variables: $prepVars"
