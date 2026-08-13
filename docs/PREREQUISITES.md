# Host prerequisites and preflight

The tested host was Windows x64. The host runs modern QEMU directly and runs
PANDA inside a Linux container. These are two separate virtualization paths:

- modern QEMU uses WHPX for fast guest preparation;
- PANDA uses its own software translator inside Docker and does not inherit
  WHPX acceleration.

## Required software

Install or provide:

- 64-bit Windows 10 or 11 with hardware virtualization enabled in firmware;
- PowerShell 5.1 or newer;
- [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/),
  configured for Linux containers;
- a 64-bit Windows build of [QEMU](https://www.qemu.org/download/) containing
  `qemu-system-x86_64`, `qemu-img`, and EDK2/OVMF firmware;
- Python 3;
- the Windows OpenSSH client; and
- an already-installed, licensed Windows 11 VDI meeting
  [the source-VM requirements](SOURCE-VM.md).

The QEMU project links to Windows installers and MSYS2 packages but does not
itself publish one canonical Windows installer. Record where your binary came
from and its exact `--version` output.

## WHPX host setup

WHPX requires CPU virtualization in the host firmware and the Windows
Hypervisor Platform optional feature. Inspect it in elevated PowerShell:

```powershell
Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform
Get-CimInstance Win32_ComputerSystem |
  Select-Object HypervisorPresent
```

If WHPX is unavailable and you intend to enable it, use an elevated prompt and
reboot afterward:

```powershell
Enable-WindowsOptionalFeature `
  -Online `
  -FeatureName HypervisorPlatform `
  -All
```

Changing Windows optional features modifies the host. Review the command and
your organization's virtualization policy first. This project does **not**
require disabling host Hyper-V or host VBS. The guest bootstrap disables those
features inside the disposable guest only.

If WHPX remains unavailable, `Start-QemuPrep.ps1 -Accelerator tcg` works
without hardware acceleration but is much slower.

## Docker details

Docker Desktop must be running and report a Linux engine:

```powershell
docker info --format '{{.OSType}}'
```

The result must be `linux`. On some Docker Desktop versions, the drive holding
`WorkRoot` must be allowed in Docker file-sharing settings. A mount error such
as “drive is not shared” is a Docker host configuration problem, not a PANDA
disk-format problem.

Docker's WSL 2 or Hyper-V backend can coexist with the WHPX preparation path on
the tested host. Do not disable the host hypervisor merely because the guest
bootstrap disables the guest hypervisor.

## QEMU details

Confirm that your build includes the required accelerator and machine type:

```powershell
& 'C:\Program Files\qemu\qemu-system-x86_64.exe' -accel help
& 'C:\Program Files\qemu\qemu-system-x86_64.exe' -machine help |
  Select-String 'pc-q35-5.2'
```

The compatibility launcher requires `pc-q35-5.2`. The GUI-suffixed
`qemu-system-x86_64w.exe` does not show a console window; temporarily point
`QemuSystem` at `qemu-system-x86_64.exe` when diagnosing startup errors.

Firmware filenames vary between QEMU distributions. Configure one x86-64 EDK2
code image and its matching writable variable-store template. Do not share one
writable variable store between concurrently running VMs.

## Storage and ports

Plan for at least:

- the original VDI;
- a preparation overlay;
- a standalone flattened seed approximately as large as allocated guest data;
- an active PANDA overlay; and
- potentially large recordings and analysis logs.

Sixty GiB free is only a starting estimate. Put `WorkRoot` on NTFS or another
filesystem that supports large files reliably. Avoid cloud-synchronized
folders and removable media.

The default loopback ports must be free:

| Purpose | Host port |
|---|---:|
| Guest SSH | 2222 |
| PANDA HMP monitor | 4444 |
| Modern-QEMU QMP | 5955 |
| noVNC | 6080 |

Change conflicts in `config/panda.psd1`, not in only one launcher.

## Automated preflight

After creating `config/panda.psd1`, run:

```powershell
.\scripts\host\Test-HostPrerequisites.ps1
```

It validates commands, configured files, source format, QEMU capabilities,
Docker engine type, disk space, and ports. WHPX checks are warnings because TCG
remains a valid fallback. Resolve required failures before generating disks.
