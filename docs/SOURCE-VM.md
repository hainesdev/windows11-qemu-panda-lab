# Source Windows 11 VM requirements

This repository starts from an **already-installed Windows 11 VDI**. It does
not currently create a VM from a Windows ISO.

That boundary is intentional. A standard Windows 11 installation expects two
or more virtual processors, UEFI, Secure Boot capability, and TPM 2.0. The
current preparation launcher does not attach installation media or emulate a
TPM, and PANDA's final single-vCPU QEMU 2.9-era machine is outside Microsoft's
normal Windows 11 baseline. See
[Microsoft's Windows 11 VM requirements](https://learn.microsoft.com/windows/whats-new/windows-11-requirements).

Do not interpret “use an existing VDI” as instructions to bypass Windows
requirements. Install and license Windows in a supported hypervisor first,
then make an offline clone for this experimental lab.

## Required starting state

Before creating the preparation overlay, verify that the source:

- is a complete VDI, not merely the base of an unresolved VirtualBox snapshot
  chain;
- contains a 64-bit Windows 11 installation using GPT and UEFI boot;
- was shut down fully, not paused, saved, hibernated, or left in Fast Startup
  hybrid shutdown state;
- has access to its BitLocker/device-encryption recovery key, if encryption is
  enabled;
- can tolerate changing CPU, firmware variables, storage controller, display,
  and NIC models; and
- has a valid Windows license for the intended use.

Never point these scripts at a VDI currently opened by VirtualBox.

## Consolidate VirtualBox snapshots

If VirtualBox reports snapshots, clone the **current machine state** into a new
full VDI rather than copying only the original base file. The exact operation
depends on the VirtualBox version and storage layout. Verify the clone by
booting it once before treating it as the source.

The source VDI should be treated as immutable after its hash is recorded. The
scripts put preparation writes into a qcow2 overlay, but host permissions are
still the operator's responsibility.

## Encryption and TPM-bound state

Moving an installed guest to different virtual firmware or removing its vTPM
can trigger BitLocker recovery. Before cloning:

1. back up the recovery key outside the VM;
2. inspect encryption state with `manage-bde -status` in elevated guest
   PowerShell; and
3. either decrypt the lab clone or suspend protectors for the hardware move.

Do not proceed without the recovery key. A recovery prompt under PANDA can
look like a boot failure, and typing a long recovery key through a very slow
console is avoidable.

Windows Hello PINs and other TPM-bound credentials can also stop working after
the move. Retain a password-capable local or Microsoft account for the first
QEMU boot; do not rely exclusively on a PIN tied to the previous virtual TPM.

## Full shutdown

Inside the source guest, disable hibernation/Fast Startup for the analysis
clone and shut down completely:

```powershell
powercfg.exe /hibernate off
shutdown.exe /s /t 0
```

Wait until the hypervisor reports the VM powered off. Copying a live or
hibernated disk can produce filesystem recovery, boot loops, or state tied to
the previous virtual hardware.

## Driver expectations

The preparation VM presents:

- Q35/UEFI;
- an IDE disk;
- VGA;
- xHCI keyboard and tablet; and
- an Intel `e1000` NIC.

These choices favor Windows inbox drivers and the older PANDA device model.
`e1000e` did not provide a usable link in the originating experiment.
VirtualBox Guest Additions may remain installed, but remove them from the lab
clone if they cause startup services, display problems, or anti-VM noise.

## First modern-QEMU boot checklist

The first hardware change can take longer than later WHPX boots. Require:

- no BitLocker recovery prompt;
- Windows desktop and keyboard/pointer input;
- correct system clock;
- an `e1000` adapter in Device Manager without an error;
- working DNS/network access when NAT is intended; and
- a clean shutdown afterward.

Only then provision OpenSSH and create the standalone PANDA seed.

Finish pending Windows updates and reboots before flattening the seed. Record
the update/build state and avoid changing it after recordings exist. Windows
Update, Defender scans, search indexing, and component servicing can add hours
of background work under PANDA; record their state rather than silently
disabling security software.
