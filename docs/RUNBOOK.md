# Complete runbook

This runbook starts with an existing licensed Windows 11 VDI. If you are
installing Windows from ISO, first create and install a conventional modern
QEMU VM, then use its disk as the source described here.

Run host commands from the repository root in PowerShell.

## 1. Verify prerequisites

```powershell
docker version
& 'C:\Program Files\qemu\qemu-system-x86_64.exe' --version
& 'C:\Program Files\qemu\qemu-img.exe' --version
ssh -V
python --version
```

Docker must be using Linux containers. Confirm adequate disk space:

```powershell
Get-Volume | Select-Object DriveLetter, SizeRemaining
```

Plan for the source disk, preparation overlay, flattened seed, writable PANDA
overlay, and recordings. Sixty GiB is a practical minimum, not a guarantee.

## 2. Configure local paths

```powershell
Copy-Item .\config\panda.example.psd1 .\config\panda.psd1
notepad .\config\panda.psd1
```

Set at least:

- `VmRoot` and `BaseDisk` for the source VDI;
- `WorkRoot` for all generated artifacts;
- QEMU executable and EDK2/OVMF firmware paths;
- unused loopback ports if 2222, 4444, 5955, or 6080 are occupied.

The local configuration is ignored by Git.

## 3. Create the preparation disk

```powershell
.\scripts\host\Initialize-QemuPrep.ps1
```

This creates:

```text
source Windows11.vdi              read-only backing source
  -> qemu/Windows11-panda-prep.qcow2   writable preparation overlay
```

It also copies a private OVMF variable store. Existing files are preserved;
the script does not overwrite a preparation disk.

## 4. Prepare Windows quickly

```powershell
.\scripts\host\Start-QemuPrep.ps1 -Accelerator whpx
```

The default preparation VM has two vCPUs, 4096 MiB RAM, Q35, UEFI, an IDE
disk, VGA, xHCI input, an `e1000` NIC, and TCP 2222 forwarded to guest TCP 22.

Complete Windows setup and allow the desktop to settle before provisioning
the control channel.

## 5. Provision guest OpenSSH and compatibility settings

Generate a dedicated Ed25519 identity and bootstrap:

```powershell
.\scripts\host\New-GuestBootstrap.ps1
```

The script prints a Python command. Run it on the host and leave it running.
Then open **elevated Windows PowerShell** in the guest and execute:

```powershell
irm http://10.0.2.2:8000/s|iex
```

`10.0.2.2` is QEMU user networking's conventional host-side address. The
generated endpoint contains the SSH **public** key only. The private key remains
under `WorkRoot\ssh`.

The guest script:

- disables guest Hyper-V, VSM, VBS, HVCI, and related optional features;
- disables automatic reboot after a crash;
- installs and starts Windows OpenSSH Server;
- creates a local `panda` administrator with a random noninteractive password;
- installs the generated administrator public key with restrictive ACLs;
- enables public-key authentication and disables SSH password authentication;
- selects Windows PowerShell as the SSH default shell; and
- creates an inbound guest firewall rule for TCP 22.

Reboot Windows. Then validate from the host:

```powershell
.\scripts\host\Test-GuestSsh.ps1
```

Require authenticated command execution—not merely an open TCP port. Shut
Windows down normally after the test.

## 6. Optional TCG compatibility boot

Modern QEMU can approximate the single-core software-emulation environment
without PANDA instrumentation:

```powershell
.\scripts\host\Start-QemuPrep.ps1 -Accelerator tcg
```

This uses one `Westmere` vCPU and `pc-q35-5.2`. It will be substantially slower
than WHPX. Re-run `Test-GuestSsh.ps1` after Windows boots. Passing this test is
useful evidence, but it does not guarantee boot success under PANDA's older
QEMU machine and CPU implementation.

## 7. Flatten and initialize PANDA

Make sure every QEMU VM using these disks is stopped, then run:

```powershell
.\scripts\host\Initialize-Panda.ps1
```

The initializer:

1. builds the pinned PANDA container extension;
2. flattens the preparation overlay into a standalone qcow2 seed with modern
   host `qemu-img`;
3. creates a small writable qcow2 overlay over that seed;
4. copies private PANDA firmware files; and
5. prints the final backing chain.

The required final chain is:

```text
Windows11-panda-active.qcow2
  -> Windows11-panda-seed.qcow2
       -> no backing file
```

If the source VDI still appears beneath the seed, stop. PANDA's QEMU 2.9
recording snapshot path may fail while migrating a block graph that contains a
VDI node.

## 8. Start PANDA

Start with restricted networking:

```powershell
.\scripts\host\Start-Panda.ps1 -Network offline
```

The noVNC console opens in a browser. To suppress that:

```powershell
.\scripts\host\Start-Panda.ps1 -Network offline -NoBrowser
```

Use NAT only when the experiment requires it:

```powershell
.\scripts\host\Start-Panda.ps1 -Network nat
```

PANDA uses one emulated vCPU. Increasing the Docker CPU allocation does not
turn deterministic guest execution into hardware acceleration or multicore
record/replay.

## 9. Require boot and application readiness

Before application work, require all of the following:

1. Windows reaches a usable desktop in noVNC.
2. `Test-GuestSsh.ps1` authenticates and executes commands.
3. The intended application starts and its scenario can be exercised.

If any gate fails, the infrastructure may still support a synthetic smoke
recording, but the guest is not application-ready.

Do not use a fixed 10- or 20-minute timeout as proof that Windows is hung under
PANDA. The originating guest fully booted only after a much longer wait. Sample
registers and block I/O through the monitor; if they continue changing, extend
the observation window.

## 10. Validate snapshot, record, and replay

Create and list a snapshot:

```powershell
.\scripts\host\Save-PandaSnapshot.ps1 -Name snapshot-gate
.\scripts\host\Invoke-PandaMonitor.ps1 'info snapshots'
```

The snapshot must have nonzero VM state and no migration error.

Record a short interval:

```powershell
.\scripts\host\Start-PandaRecording.ps1 -Name rr-smoke
Start-Sleep -Seconds 3
.\scripts\host\Stop-PandaRecording.ps1
```

Both recording files must be nonempty:

```powershell
$config = Import-PowerShellDataFile .\config\panda.psd1
Get-Item `
  (Join-Path $config.WorkRoot 'recordings\rr-smoke-rr-snp'), `
  (Join-Path $config.WorkRoot 'recordings\rr-smoke-rr-nondet.log') |
  Select-Object Name, Length
```

Stop the live VM before replay:

```powershell
.\scripts\host\Stop-Panda.ps1
.\scripts\host\Analyze-PandaReplay.ps1 -Name rr-smoke
```

Success requires replay completion and a nonempty
`analyses\rr-smoke-coverage.csv`.

## 11. Record an application scenario

Use a fresh experiment name for every scenario:

```powershell
.\scripts\host\Start-Panda.ps1 -Network offline
.\scripts\host\Start-PandaRecording.ps1 `
  -Name target-baseline-01 `
  -Snapshot root

# Exercise exactly one documented behavior in the guest.

.\scripts\host\Stop-PandaRecording.ps1
.\scripts\host\Stop-Panda.ps1
.\scripts\host\Analyze-PandaReplay.ps1 -Name target-baseline-01
```

Preserve together:

- `-rr-snp` and `-rr-nondet.log`;
- coverage CSV and PANDA log;
- replay log;
- hashes of the input disk, target binary, firmware, and container image;
- the exact `container/common.sh` revision; and
- operator notes and wall-clock timestamps.

## 12. Moving the lab

For an existing recording, treat these as one compatibility set:

- PANDA container digest;
- `common.sh` machine definition;
- standalone seed and active overlay state;
- OVMF code and variable store; and
- recording snapshot plus nondeterminism log.

Re-run the smoke replay after moving to another host before collecting new
evidence.
