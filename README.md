# Windows 11 on QEMU and PANDA

An experimental, reproducible lab for preparing a Windows 11 guest with modern
QEMU on a Windows host, running the same disk under
[PANDA](https://github.com/panda-re/panda), and validating deterministic
record/replay.

This repository contains scripts and documentation only. It does **not**
contain Windows installation media, VM disks, firmware copied from QEMU, SSH
private keys, PANDA recordings, or proprietary software.

> [!IMPORTANT]
> PANDA's current public Docker image is based on a QEMU 2.9-era fork and uses
> software translation for record/replay. Windows 11 is outside PANDA's
> documented Windows OSI profiles. A record/replay smoke test can succeed even
> when a specific Windows 11 image never becomes interactively usable under
> PANDA. Treat this project as a compatibility lab, not a claim of general
> Windows 11 support.

## What this project provides

- A parameterized PowerShell configuration with no machine-specific paths.
- A fast modern-QEMU/WHPX launcher for installing and preparing Windows 11.
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

## Quick start

1. Copy the example configuration and edit its paths:

   ```powershell
   Copy-Item .\config\panda.example.psd1 .\config\panda.psd1
   notepad .\config\panda.psd1
   ```

2. Create the modern-QEMU preparation overlay:

   ```powershell
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

- [Complete runbook](docs/RUNBOOK.md)
- [Compatibility status and limitations](docs/COMPATIBILITY.md)
- [Validation gates](docs/VALIDATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Security and isolation](SECURITY.md)

## What was validated

The originating lab validated the PANDA infrastructure with a completed
388,439,348-instruction record/replay and a nonempty ASID/basic-block coverage
report. The tested Windows 11 disk booted and accepted SSH under modern QEMU,
but it did not reach an interactive desktop or SSH under the tested PANDA
configuration. Full evidence and the distinction between infrastructure and
guest readiness are documented in [docs/VALIDATION.md](docs/VALIDATION.md).

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
