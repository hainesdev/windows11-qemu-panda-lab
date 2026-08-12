[CmdletBinding()]
param(
    [ValidateSet('offline', 'nat')]
    [string]$Network = 'offline',
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot 'Get-LabConfig.ps1')

function Resolve-WorkPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    Join-Path $config.WorkRoot $Path
}

docker info --format '{{.ServerVersion}}' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop is not running.' }

$activeDisk = Resolve-WorkPath $config.ActiveDisk
$code = Resolve-WorkPath $config.PandaCode
$vars = Resolve-WorkPath $config.PandaVars
foreach ($required in $config.WorkRoot, $activeDisk, $code, $vars) {
    if (-not (Test-Path -LiteralPath $required)) { throw "PANDA is not initialized. Missing: $required" }
}

$running = docker ps --filter "name=^/$($config.Container)$" --format '{{.Names}}'
if ($running -ne $config.Container) {
    $existing = docker ps --all --filter "name=^/$($config.Container)$" --format '{{.Names}}'
    if ($existing -eq $config.Container) { docker rm $config.Container | Out-Null }

    $workMount = "$($config.WorkRoot):/work"
    $dockerArgs = @(
        'run', '--detach', '--rm'
        '--name', $config.Container
        '--hostname', $config.Container
        '--memory', '8g'
        '--cpus', '6'
        '--pids-limit', '4096'
        '--security-opt', 'no-new-privileges'
        '--cap-drop', 'ALL'
        '--publish', "127.0.0.1:$($config.NoVncPort):6080"
        '--publish', "127.0.0.1:$($config.MonitorPort):4444"
        '--publish', "127.0.0.1:$($config.SshPort):2222"
        '--volume', $workMount
        '--env', "PANDA_NETWORK=$Network"
        '--env', "PANDA_DISK=/work/$(Split-Path $activeDisk -Leaf)"
        '--env', "PANDA_OVMF_CODE=/work/$(Split-Path $code -Leaf)"
        '--env', "PANDA_VARS=/work/$(Split-Path $vars -Leaf)"
        $config.Image
    )
    $containerId = & docker @dockerArgs
    if ($LASTEXITCODE -ne 0) { throw 'Failed to launch PANDA.' }
    Write-Host "Started PANDA container $containerId"
} else {
    Write-Host 'PANDA is already running.'
}

$url = "http://127.0.0.1:$($config.NoVncPort)/vnc.html?autoconnect=1&resize=scale&path=websockify"
$deadline = (Get-Date).AddSeconds(30)
do {
    Start-Sleep -Milliseconds 500
    try {
        $ready = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 2).StatusCode -eq 200
    } catch { $ready = $false }
} while (-not $ready -and (Get-Date) -lt $deadline)

if (-not $ready) {
    docker logs --tail 100 $config.Container
    throw 'PANDA started, but noVNC did not become ready.'
}

if (-not $NoBrowser) { Start-Process $url }
Write-Host "PANDA console: $url"
Write-Host "Guest SSH: ssh -p $($config.SshPort) panda@127.0.0.1"
Write-Host "Network mode: $Network"
