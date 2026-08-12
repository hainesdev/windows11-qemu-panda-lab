[CmdletBinding()]
param(
    [ValidateSet('whpx', 'tcg')]
    [string]$Accelerator = 'whpx',

    [ValidateRange(4096, 32768)]
    [int]$MemoryMb = 4096
)

$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot 'Get-LabConfig.ps1')

function Resolve-WorkPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    Join-Path $config.WorkRoot $Path
}

function Join-NativeArguments([string[]]$Arguments) {
    ($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '(\\*)"', '$1$1\"') + '"' }
        else { $_ }
    }) -join ' '
}

$disk = Resolve-WorkPath $config.PrepOverlay
$vars = Resolve-WorkPath $config.PrepVars
$pidFile = Join-Path $config.WorkRoot 'qemu-prep.pid'

foreach ($required in $config.QemuSystem, $config.HostOvmfCode, $disk, $vars) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required file not found: $required"
    }
}

$running = Get-Process -Name 'qemu-system-x86_64', 'qemu-system-x86_64w' -ErrorAction SilentlyContinue
if ($running) {
    throw "Another QEMU VM is running (PID: $(($running.Id | Sort-Object) -join ', '))."
}

if ($Accelerator -eq 'whpx') {
    $machine = 'q35,accel=whpx,pic=off'
    $cpuArgs = @()
    $smp = '2,sockets=1,cores=2,threads=1'
} else {
    $machine = 'pc-q35-5.2,accel=tcg'
    $cpuArgs = @('-cpu', 'Westmere')
    $smp = '1,sockets=1,cores=1,threads=1'
}

$qemuArgs = @(
    '-name', "Windows 11 PANDA preparation ($Accelerator)"
    '-machine', $machine
) + $cpuArgs + @(
    '-smp', $smp
    '-m', [string]$MemoryMb
    '-nodefaults'
    '-drive', "if=pflash,format=raw,unit=0,readonly=on,file=$($config.HostOvmfCode)"
    '-drive', "if=pflash,format=raw,unit=1,file=$vars"
    '-drive', "if=none,id=win11,format=qcow2,file=$disk,cache=writeback,discard=unmap"
    '-device', 'ide-hd,drive=win11,bus=ide.0,bootindex=1'
    '-device', 'VGA'
    '-display', 'gtk,zoom-to-fit=on'
    '-device', 'qemu-xhci,id=xhci'
    '-device', 'usb-kbd,bus=xhci.0'
    '-device', 'usb-tablet,bus=xhci.0'
    '-netdev', "user,id=net0,hostfwd=tcp:127.0.0.1:$($config.SshPort)-:22"
    '-device', 'e1000,netdev=net0,mac=08:00:27:BB:A0:A3'
    '-rtc', 'base=localtime,clock=host'
    '-boot', 'menu=on'
    '-qmp', "tcp:127.0.0.1:$($config.QmpPort),server=on,wait=off"
    '-pidfile', $pidFile
)

Write-Host "Starting the $Accelerator preparation VM. Shut Windows down normally when finished."
$argumentString = Join-NativeArguments $qemuArgs
try {
    $process = Start-Process -FilePath $config.QemuSystem -ArgumentList $argumentString -PassThru -Wait
    if ($process.ExitCode -ne 0) { throw "QEMU exited with code $($process.ExitCode)." }
}
finally {
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}
