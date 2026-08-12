[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot 'Get-LabConfig.ps1')
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$containerRoot = Join-Path $repoRoot 'container'

function Resolve-WorkPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    Join-Path $config.WorkRoot $Path
}

docker info --format '{{.ServerVersion}}' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop is not running with Linux containers.' }

$prepOverlay = Resolve-WorkPath $config.PrepOverlay
$seedDisk = Resolve-WorkPath $config.SeedDisk
$activeDisk = Resolve-WorkPath $config.ActiveDisk
$code = Resolve-WorkPath $config.PandaCode
$vars = Resolve-WorkPath $config.PandaVars

foreach ($required in $config.QemuImg, $config.HostOvmfCode, $config.HostOvmfVars, $prepOverlay) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required file not found: $required"
    }
}

$runningQemu = Get-Process -Name 'qemu-system-x86_64', 'qemu-system-x86_64w' -ErrorAction SilentlyContinue
if ($runningQemu) {
    throw 'Shut down the preparation VM before flattening its disk.'
}

New-Item -ItemType Directory -Path $config.WorkRoot -Force | Out-Null
foreach ($name in 'recordings', 'analyses', 'logs') {
    New-Item -ItemType Directory -Path (Join-Path $config.WorkRoot $name) -Force | Out-Null
}

& docker build --tag $config.Image $containerRoot
if ($LASTEXITCODE -ne 0) { throw 'Failed to build the PANDA lab image.' }

if (-not (Test-Path -LiteralPath $seedDisk)) {
    $temporarySeed = "$seedDisk.flattening"
    if (Test-Path -LiteralPath $temporarySeed) {
        throw "Incomplete seed already exists: $temporarySeed. Inspect and remove it before retrying."
    }

    & $config.QemuImg convert -p -f qcow2 -O qcow2 $prepOverlay $temporarySeed
    if ($LASTEXITCODE -ne 0) { throw 'Failed to flatten the prepared guest.' }
    Move-Item -LiteralPath $temporarySeed -Destination $seedDisk
} else {
    Write-Host "Keeping existing standalone seed: $seedDisk"
}

if (-not (Test-Path -LiteralPath $activeDisk)) {
    $workMount = "$($config.WorkRoot):/work"
    $seedName = Split-Path $seedDisk -Leaf
    $activeName = Split-Path $activeDisk -Leaf
    & docker run --rm --volume $workMount $config.Image `
        qemu-img create -f qcow2 -F qcow2 -b "/work/$seedName" "/work/$activeName"
    if ($LASTEXITCODE -ne 0) { throw 'Failed to create the PANDA writable overlay.' }
} else {
    Write-Host "Keeping existing PANDA overlay: $activeDisk"
}

if (-not (Test-Path -LiteralPath $code)) {
    Copy-Item -LiteralPath $config.HostOvmfCode -Destination $code
}
if (-not (Test-Path -LiteralPath $vars)) {
    Copy-Item -LiteralPath $config.HostOvmfVars -Destination $vars
}

$workMount = "$($config.WorkRoot):/work"
$activeName = Split-Path $activeDisk -Leaf
& docker run --rm --volume $workMount $config.Image `
    qemu-img info --backing-chain "/work/$activeName"
if ($LASTEXITCODE -ne 0) { throw 'PANDA disk validation failed.' }

Write-Host "PANDA initialized in $($config.WorkRoot)"
Write-Host 'Confirm that the seed has no backing file before recording.'
