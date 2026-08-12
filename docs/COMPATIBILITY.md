# Compatibility status and design choices

## Tested originating environment

| Component | Tested value |
|---|---|
| Host architecture | Windows x64 |
| Host QEMU | 11.0.50 development build |
| PANDA release | 1.8.83 |
| PANDA embedded QEMU | 2.9.1 |
| PANDA base image | `pandare/panda@sha256:e4bb0346e9f9cd9f0b4a2f75b353cbf041005687b4af47d5705cfee054aec71b` |
| PANDA guest machine | `pc-q35-2.9`, UEFI, one vCPU, 4096 MiB |
| PANDA CPU | augmented `qemu64`, `GenuineIntel` vendor |
| Disk | IDE-attached qcow2 overlay over a standalone qcow2 seed |
| NIC | `e1000` with QEMU user networking |

These values document one experiment; they are not a universal support
matrix.

## Why PANDA is slow

PANDA's deterministic record/replay relies on software translation and
instruction counting. The public PANDA project has historically not supported
hardware virtualization for this workflow, and its record/replay is not a
multicore acceleration path. More host RAM or Docker CPUs can prevent resource
starvation but cannot make the single emulated guest CPU behave like WHPX.

Relevant upstream discussions:

- [PANDA performance and hardware acceleration discussion](https://github.com/panda-re/panda/issues/198)
- [PANDA QEMU modernization discussion](https://github.com/panda-re/panda/issues/570)
- [QEMU instruction-counting design](https://www.qemu.org/docs/master/devel/tcg-icount.html)
- [QEMU record/replay](https://www.qemu.org/docs/master/system/replay.html)

## Windows 11 status

Windows 11 normally expects at least two cores, UEFI, TPM 2.0, and other modern
platform features. This lab deliberately presents one emulated vCPU under
PANDA for deterministic execution. A previously installed guest may execute
in that environment, but this is outside the normal Windows 11 hardware
baseline. See [Microsoft's Windows 11 requirements](https://learn.microsoft.com/windows/whats-new/windows-11-requirements).

PANDA's documented Windows OSI profiles cover older Windows releases rather
than Windows 10 or 11. Consequently this project uses `coverage:mode=asid-block`,
which does not depend on a Windows 11 OSI profile. Do not assume that process
names, module lists, named syscall profiles, or OSI-filtered analysis are
correct without building and independently validating an appropriate profile.

- [PANDA OSI plugin documentation](https://github.com/panda-re/panda/blob/dev/panda/plugins/osi/README.md)
- [PANDA coverage plugin documentation](https://github.com/panda-re/panda/blob/dev/panda/plugins/coverage/README.md)

## Observed CPU and device behavior

In the originating lab:

- modern QEMU booted the prepared guest successfully with a `Westmere` CPU and
  `e1000` NIC under TCG;
- PANDA progressed farthest with the augmented `qemu64` CPU in `common.sh`;
- PANDA named `Westmere`, `Broadwell`, `Skylake`, and `max` experiments failed
  earlier in boot;
- `e1000e` did not produce a usable guest link, while `e1000` did; and
- writable raw pflash caused recording snapshot failure unless the variable
  store used `snapshot=on`.

These are empirical compatibility choices, not required settings for every
Windows image.

## Time-sensitive network protocols

PANDA should not be the live network-facing recorder for a protocol with an
external deadline. The remote peer measures host wall time while the PANDA
guest is executing slowly.

Use this split instead:

1. Capture a successful exchange in hardware-accelerated QEMU or on a dedicated
   physical analysis machine.
2. Record packet timestamps, DNS, endpoints, process/socket attribution, and
   the relevant plaintext or cryptographic boundaries.
3. Build a stateful local responder. Static packet replay is usually
   insufficient when timestamps, nonces, ephemeral keys, or message
   authentication codes are involved.
4. Redirect an offline clone to the local responder and record only the short
   analysis window under PANDA.

A transparent forwarding proxy helps observation but cannot eliminate the
remote peer's timeout between handshake flights.

## Alternatives

- Modern QEMU has upstream record/replay and network replay filters, but it
  still relies on `icount` and software emulation for deterministic execution.
- Hardware-assisted tracing such as Intel PT/EPT can reduce perturbation for
  live acquisition, at the cost of different tooling and deployment
  constraints.
- Windows Time Travel Debugging provides user-mode recording, but it injects
  into the target and can conflict with anti-instrumentation measures.

Choose the tool based on which property matters most: wall-clock fidelity,
stealth, complete-machine replay, or introspection quality.
