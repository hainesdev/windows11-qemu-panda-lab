[CmdletBinding()]
param(
    [string]$OutputPath,
    [switch]$IncludeLargeFileHashes
)

$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot 'Get-LabConfig.ps1')
. (Join-Path $PSScriptRoot 'LabPaths.ps1')
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$qemuInspector = $config.QemuSystem
if ($qemuInspector -match 'w\.exe$') {
    $consoleQemu = $qemuInspector -replace 'w\.exe$', '.exe'
    if (Test-Path -LiteralPath $consoleQemu) { $qemuInspector = $consoleQemu }
}

if (-not $OutputPath) {
    $manifestRoot = Join-Path $config.WorkRoot 'manifests'
    New-Item -ItemType Directory -Path $manifestRoot -Force | Out-Null
    $OutputPath = Join-Path $manifestRoot "lab-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
}

function Get-CommandText([scriptblock]$Command) {
    try { ((& $Command 2>&1) | Out-String).Trim() } catch { "ERROR: $($_.Exception.Message)" }
}

function Get-FileFact([string]$Path, [bool]$Hash) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [ordered]@{ Path = $Path; Exists = $false }
    }
    $item = Get-Item -LiteralPath $Path
    $fact = [ordered]@{
        Path = $item.FullName
        Exists = $true
        Bytes = $item.Length
        LastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('o')
    }
    if ($Hash) { $fact.Sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
    $fact
}

$baseDisk = Join-Path $config.VmRoot $config.BaseDisk
$fileFacts = [ordered]@{
    SourceDisk = Get-FileFact $baseDisk ([bool]$IncludeLargeFileHashes)
    PrepOverlay = Get-FileFact (Resolve-LabWorkPath $config $config.PrepOverlay) ([bool]$IncludeLargeFileHashes)
    SeedDisk = Get-FileFact (Resolve-LabWorkPath $config $config.SeedDisk) ([bool]$IncludeLargeFileHashes)
    ActiveDisk = Get-FileFact (Resolve-LabWorkPath $config $config.ActiveDisk) ([bool]$IncludeLargeFileHashes)
    HostOvmfCode = Get-FileFact $config.HostOvmfCode $true
    HostOvmfVars = Get-FileFact $config.HostOvmfVars $true
    PandaOvmfCode = Get-FileFact (Resolve-LabWorkPath $config $config.PandaCode) $true
    PandaOvmfVars = Get-FileFact (Resolve-LabWorkPath $config $config.PandaVars) $true
}

$imageId = Get-CommandText { docker image inspect $config.Image --format '{{.Id}}' }
$manifest = [ordered]@{
    GeneratedAt = (Get-Date).ToString('o')
    Warning = 'This private manifest contains local paths. Sanitize paths before publishing.'
    RepositoryCommit = Get-CommandText { git -C $repoRoot rev-parse HEAD }
    Host = [ordered]@{
        OperatingSystem = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, OSArchitecture
        ComputerSystem = Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, HypervisorPresent, TotalPhysicalMemory
        Processor = Get-CimInstance Win32_Processor | Select-Object Manufacturer, Name, NumberOfCores, NumberOfLogicalProcessors
        PowerShell = $PSVersionTable.PSVersion.ToString()
    }
    Tools = [ordered]@{
        Qemu = Get-CommandText { & $qemuInspector --version }
        QemuImg = Get-CommandText { & $config.QemuImg --version }
        Docker = Get-CommandText { docker version --format 'Client={{.Client.Version}} Server={{.Server.Version}} OSType={{.Server.Os}}' }
        Python = Get-CommandText { python --version }
        Ssh = Get-CommandText { ssh -V }
        PandaImage = $config.Image
        PandaImageId = $imageId
        PandaQemu = if ($imageId -and $imageId -notmatch '^ERROR:') {
            Get-CommandText { docker run --rm $config.Image panda-system-x86_64 --version }
        } else { 'image not built' }
    }
    Configuration = $config
    Files = $fileFacts
}

New-Item -ItemType Directory -Path (Split-Path ([IO.Path]::GetFullPath($OutputPath)) -Parent) -Force | Out-Null
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host "Manifest written to: $OutputPath"
if (-not $IncludeLargeFileHashes) {
    Write-Host 'Large disk hashes were skipped. Use -IncludeLargeFileHashes for evidence-grade provenance.'
}
