# Windows 11 on QEMU and PANDA

Prepare Windows 11 with fast, modern QEMU; boot the same guest under
[PANDA](https://github.com/panda-re/panda); record a complete execution once;
and replay it repeatedly for offline dynamic analysis.

## Purpose

PANDA can record nondeterministic events around an entire virtual machine and
later reproduce the same instruction stream. That is valuable when an analyst
needs to revisit a rare, stateful, or difficult-to-trigger execution without
making the application perform it again.

Getting a modern Windows guest into that environment is the difficult part.
PANDA's public runtime is based on an older QEMU fork, while Windows 11 expects
modern virtual hardware and is painfully slow under single-vCPU software
emulation. This project documents and automates the compatibility bridge:

1. prepare and control an existing Windows 11 VDI under hardware-accelerated
   QEMU;
2. convert it into a safe disk chain accepted by PANDA's older QEMU runtime;
3. boot Windows 11 under PANDA and take reusable snapshots;
4. record a bounded guest execution; and
5. replay it offline with coverage or additional PANDA analysis plugins.

The result is a reusable whole-system analysis lab, not simply another Windows
VM launcher.

## What can you do with it?

An analyst can use this project to:

- preserve an original Windows 11 VDI while experimenting in disposable
  qcow2 overlays;
- automate the guest through key-only SSH and remote PowerShell;
- create a clean pre-experiment snapshot and restore the same starting state;
- record complete machine execution and its nondeterministic inputs;
- replay the exact recorded execution without reconnecting to the original
  service or manually reproducing the UI sequence;
- generate address-space/basic-block coverage that does not require a Windows
  11 OSI profile;
- compare traces from different inputs or application behaviors; and
- retain versions, hashes, timing, logs, and recording metadata so another
  analyst can reproduce the workflow and audit the evidence.

Typical uses include reverse engineering, unpacking, malware or suspicious
software analysis, studying anti-debugging behavior, analyzing rare crashes,
and developing PANDA plugins. PANDA does not make instrumentation invisible,
but whole-system recording can reduce dependence on an in-process debugger and
makes post-execution analysis repeatable.

```text
Existing Windows 11 VDI
        |
        v
Fast QEMU preparation and guest automation
        |
        v
Slow PANDA boot -> snapshot -> bounded recording
        |
        v
Repeatable offline replay -> coverage / plugins / evidence
```

## Scope and limitations

This repository contains scripts and documentation only. It does **not**
contain Windows installation media, VM disks, firmware copied from QEMU, SSH
private keys, PANDA recordings, or proprietary software.

It starts from an already-installed, licensed Windows 11 VDI. It is not a
Windows installer, a fast general-purpose sandbox, or a guarantee that every
Windows build and application will work with PANDA.

> [!IMPORTANT]
> PANDA's current public Docker image is based on a QEMU 2.9-era fork and uses
> software translation for record/replay. Windows 11 is outside PANDA's
> documented Windows OSI profiles. The originating Windows 11 guest did fully
> boot under PANDA, but startup and interaction were extremely slow. Treat this
> project as a compatibility lab, not a claim that every Windows 11 build will
> boot or perform acceptably. Workloads with an external wall-clock deadline
> should be captured in a fast VM and reproduced against a local responder
> before PANDA analysis.

## What the repository provides

- A parameterized PowerShell configuration with no machine-specific paths.
- A fast modern-QEMU/WHPX launcher for preparing an already-installed Windows
  11 VDI.
- An optional modern-QEMU TCG compatibility boot using one `Westmere` vCPU.
- Idempotent guest preparation that disables guest Hyper-V/VBS and provisions
  key-only OpenSSH control.
- A pinned PANDA container extended with OVMF, noVNC, and QEMU disk utilities.
- Safe disk layering: source VDI, preparation overlay, standalone seed, and
  disposable PANDA overlay.
- Loopback-only noVNC, monitor, and SSH ports.
- Snapshot, record, replay, and ASID/basic-block coverage helpers.
- Fail-closed validation of recording and replay artifacts.

## Architecture

```mermaid
flowchart LR
    VDI["Licensed Windows 11 VDI<br/>read-only source"]
    PREP["Modern QEMU overlay<br/>WHPX for setup; TCG for compatibility"]
    SEED["Standalone qcow2 seed<br/>no VDI backing node"]
    ACTIVE["Disposable PANDA overlay"]
    PANDA["PANDA / QEMU 2.9.1<br/>single-vCPU TCG"]
    RR["rr-snp + rr-nondet.log"]
    REPLAY["Offline deterministic replay"]
    COV["ASID/basic-block coverage"]

    VDI --> PREP -->|"qemu-img convert"| SEED --> ACTIVE --> PANDA
    PANDA -->|"record"| RR --> REPLAY --> COV
```

The source VDI and standalone seed are not routine writable disks. Guest
changes are isolated in qcow2 overlays.

## Requirements

- Windows 10 or 11 x64 host with PowerShell 5.1 or newer.
- Docker Desktop using Linux containers.
- QEMU for Windows, including `qemu-system-x86_64.exe`, `qemu-img.exe`, and
  EDK2/OVMF firmware.
- Python 3 for the temporary guest-bootstrap web server.
- Windows OpenSSH client.
- A licensed Windows 11 VM disk in VDI format.
- At least 60 GiB of free storage; recordings can require substantially more.

The fast preparation launcher uses WHPX. PANDA itself does not use WHPX and
will be much slower.

This project does not currently install Windows from an ISO. The starting VDI
must be a complete, fully shut-down UEFI Windows 11 installation. Read
[Source VM requirements](docs/SOURCE-VM.md) before pointing the scripts at a
VirtualBox disk; unresolved snapshots, hibernation, or TPM-bound encryption
are common sources of misleading boot failures.

## Quick start

1. Read the [host prerequisites](docs/PREREQUISITES.md) and
   [source VM requirements](docs/SOURCE-VM.md), then copy the example
   configuration and edit its paths:

   ```powershell
   Copy-Item .\config\panda.example.psd1 .\config\panda.psd1
   notepad .\config\panda.psd1
   ```

2. Run the non-mutating preflight and create the modern-QEMU preparation
   overlay:

   ```powershell
   .\scripts\host\Test-HostPrerequisites.ps1
   .\scripts\host\Initialize-QemuPrep.ps1
   ```

3. Start Windows using hardware acceleration:

   ```powershell
   .\scripts\host\Start-QemuPrep.ps1 -Accelerator whpx
   ```

4. Generate a dedicated SSH key and a short guest bootstrap:

   ```powershell
   .\scripts\host\New-GuestBootstrap.ps1
   ```

   Follow the printed instructions. Inside elevated Windows PowerShell, the
   guest command is:

   ```powershell
   irm http://10.0.2.2:8000/s|iex
   ```

5. Reboot and validate SSH. Then shut Windows down cleanly.

6. Build and initialize the PANDA disk chain:

   ```powershell
   .\scripts\host\Initialize-Panda.ps1
   ```

7. Start PANDA offline and open its console:

   ```powershell
   .\scripts\host\Start-Panda.ps1 -Network offline
   ```

8. When the guest is usable, execute the validation workflow in
   [docs/RUNBOOK.md](docs/RUNBOOK.md).

## Documentation

- [Host prerequisites and preflight](docs/PREREQUISITES.md)
- [Source Windows 11 VM requirements](docs/SOURCE-VM.md)
- [Complete runbook](docs/RUNBOOK.md)
- [Compatibility status and limitations](docs/COMPATIBILITY.md)
- [Validation gates](docs/VALIDATION.md)
- [Reproducibility and provenance](docs/REPRODUCIBILITY.md)
- [Guest changes and rollback](docs/GUEST-CHANGES.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Security and isolation](SECURITY.md)

## What was validated

The originating lab validated the PANDA infrastructure with a completed
388,439,348-instruction record/replay and a nonempty ASID/basic-block coverage
report. The tested Windows 11 disk booted under modern QEMU and eventually
booted fully under PANDA. PANDA execution was extremely slow, and earlier
fixed-duration checks ended before the desktop appeared. Full evidence and the
distinction between boot success and workload suitability are documented in
[docs/VALIDATION.md](docs/VALIDATION.md).

## Time-sensitive workloads

Do not put PANDA in the live path of a handshake governed by an external
wall-clock deadline. Record the real exchange in a hardware-accelerated VM,
build a local stateful responder, and then use PANDA against that responder for
offline analysis. A forwarding proxy captures traffic but does not eliminate
the remote peer's timeout.

## Upstream references

- [PANDA project](https://github.com/panda-re/panda)
- [PANDA documentation](https://docs.panda.re/)
- [QEMU record/replay](https://www.qemu.org/docs/master/system/replay.html)
- [QEMU user networking](https://www.qemu.org/docs/master/system/devices/net.html)
- [Windows 11 requirements](https://learn.microsoft.com/windows/whats-new/windows-11-requirements)

## License

The original material in this repository is available under the
[MIT License](LICENSE). Windows, QEMU, PANDA, Docker, and other third-party
components retain their own licenses and terms.
