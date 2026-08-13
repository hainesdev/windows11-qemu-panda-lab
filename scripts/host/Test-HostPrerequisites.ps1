[CmdletBinding()]
param(
    [ValidateRange(20, 2048)]
    [int]$MinimumFreeGiB = 60
)

$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot 'Get-LabConfig.ps1')
$checks = [Collections.Generic.List[object]]::new()

function Add-Check([string]$Name, [bool]$Passed, [string]$Detail, [bool]$Required = $true) {
    $checks.Add([pscustomobject]@{
        Check = $Name
        Result = if ($Passed) { 'PASS' } elseif ($Required) { 'FAIL' } else { 'WARN' }
        Detail = $Detail
    })
}

Add-Check '64-bit PowerShell' ([Environment]::Is64BitProcess) "$([Environment]::Is64BitProcess)"
Add-Check 'PowerShell 5.1+' ($PSVersionTable.PSVersion -ge [version]'5.1') "$($PSVersionTable.PSVersion)"

foreach ($command in 'docker.exe', 'ssh.exe', 'ssh-keygen.exe', 'python.exe') {
    $resolved = Get-Command $command -ErrorAction SilentlyContinue
    Add-Check "Command $command" ([bool]$resolved) $(if ($resolved) { $resolved.Source } else { 'not found in PATH' })
}

$baseDisk = Join-Path $config.VmRoot $config.BaseDisk
foreach ($entry in ([ordered]@{
    QemuSystem = $config.QemuSystem
    QemuImg = $config.QemuImg
    OvmfCode = $config.HostOvmfCode
    OvmfVars = $config.HostOvmfVars
    SourceVdi = $baseDisk
}).GetEnumerator()) {
    Add-Check $entry.Key (Test-Path -LiteralPath $entry.Value -PathType Leaf) $entry.Value
}

$qemuInspector = $config.QemuSystem
if ($qemuInspector -match 'w\.exe$') {
    $consoleQemu = $qemuInspector -replace 'w\.exe$', '.exe'
    if (Test-Path -LiteralPath $consoleQemu) { $qemuInspector = $consoleQemu }
}
if (Test-Path -LiteralPath $qemuInspector) {
    $accelerators = (& $qemuInspector -accel help 2>&1) -join "`n"
    Add-Check 'QEMU WHPX accelerator' ($accelerators -match '(?m)^whpx\s*$') 'Run `qemu-system-x86_64 -accel help` to inspect.'
    $machines = (& $qemuInspector -machine help 2>&1) -join "`n"
    Add-Check 'QEMU pc-q35-5.2 machine' ($machines -match '(?m)^pc-q35-5\.2\s') 'Required by the TCG compatibility launcher.'
}

$computerSystem = Get-CimInstance Win32_ComputerSystem
Add-Check 'Host hypervisor active' ([bool]$computerSystem.HypervisorPresent) "HypervisorPresent=$($computerSystem.HypervisorPresent)" $false
try {
    $whpFeature = Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -ErrorAction Stop
    Add-Check 'Windows Hypervisor Platform' ($whpFeature.State -eq 'Enabled') "State=$($whpFeature.State)" $false
} catch {
    Add-Check 'Windows Hypervisor Platform' ([bool]$computerSystem.HypervisorPresent) 'Feature-state query requires elevation; active host hypervisor and QEMU WHPX capability were checked.' $false
}

try {
    $dockerOs = docker info --format '{{.OSType}}' 2>$null
    Add-Check 'Docker Linux engine' ($LASTEXITCODE -eq 0 -and $dockerOs -eq 'linux') "OSType=$dockerOs"
} catch {
    Add-Check 'Docker Linux engine' $false $_.Exception.Message
}

if ((Test-Path -LiteralPath $baseDisk) -and (Test-Path -LiteralPath $config.QemuImg)) {
    try {
        $diskInfo = & $config.QemuImg info --output=json $baseDisk | ConvertFrom-Json
        Add-Check 'Source disk format' ($diskInfo.format -eq 'vdi') "format=$($diskInfo.format), virtual-size=$($diskInfo.'virtual-size')"
    } catch {
        Add-Check 'Source disk format' $false $_.Exception.Message
    }
}

$workDrive = Split-Path ([IO.Path]::GetFullPath($config.WorkRoot)) -Qualifier
try {
    $driveLetter = $workDrive.TrimEnd(':', '\')
    $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction Stop
    $freeGiB = [Math]::Round($volume.SizeRemaining / 1GB, 1)
    Add-Check "Free space (${MinimumFreeGiB} GiB minimum)" ($freeGiB -ge $MinimumFreeGiB) "$freeGiB GiB available on $workDrive"
} catch {
    Add-Check 'Free space' $false "Could not inspect volume for WorkRoot: $($_.Exception.Message)"
}

foreach ($portEntry in ([ordered]@{
    SSH = $config.SshPort
    Monitor = $config.MonitorPort
    noVNC = $config.NoVncPort
    QMP = $config.QmpPort
}).GetEnumerator()) {
    $listener = Get-NetTCPConnection -State Listen -LocalPort ([int]$portEntry.Value) -ErrorAction SilentlyContinue
    Add-Check "Port $($portEntry.Key)" (-not [bool]$listener) "TCP $($portEntry.Value) $(if ($listener) { 'is already listening' } else { 'is available' })"
}

$checks | Format-Table -AutoSize
$failed = $checks | Where-Object Result -eq 'FAIL'
if ($failed) {
    throw "$($failed.Count) required prerequisite check(s) failed. Resolve them before creating VM artifacts."
}
if ($checks | Where-Object Result -eq 'WARN') {
    Write-Warning 'Optional WHPX checks produced warnings. TCG can still run, but WHPX preparation may fail or be slow.'
}
