[CmdletBinding()]
param()

$configPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'config\panda.psd1'
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Configuration not found: $configPath. Copy config\panda.example.psd1 to config\panda.psd1 and edit it."
}

$config = Import-PowerShellDataFile -LiteralPath $configPath
$requiredKeys = @(
    'Image', 'Container', 'VmRoot', 'BaseDisk', 'WorkRoot', 'PrepOverlay',
    'PrepVars', 'SeedDisk', 'ActiveDisk', 'PandaCode', 'PandaVars',
    'QemuSystem', 'QemuImg', 'HostOvmfCode', 'HostOvmfVars', 'MonitorPort',
    'NoVncPort', 'SshPort', 'QmpPort'
)

foreach ($key in $requiredKeys) {
    if (-not $config.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$config[$key])) {
        throw "Missing configuration value: $key"
    }
}

$config
