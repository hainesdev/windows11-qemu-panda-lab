# Validation gates and evidence

Validation is divided into separate claims. Do not collapse them into “PANDA
works with Windows 11.”

## Gate A: disk safety

Pass criteria:

- source VDI remains unchanged;
- preparation writes land in its qcow2 overlay;
- standalone seed has no backing file; and
- PANDA writes land in the active qcow2 overlay.

Inspect with:

```powershell
$config = Import-PowerShellDataFile .\config\panda.psd1
& $config.QemuImg info --backing-chain `
  (Join-Path $config.WorkRoot $config.ActiveDisk)
```

## Gate B: modern-QEMU guest control

Pass criteria:

- Windows reaches the desktop using WHPX;
- `sshd` is `Running` and `Automatic`; and
- `Test-GuestSsh.ps1` authenticates with the generated key and runs commands.

An open host TCP 2222 port alone is not sufficient; QEMU opens the forwarding
listener before the guest SSH service is ready.

## Gate C: modern-QEMU TCG compatibility

Pass criteria:

- Windows reaches the desktop using `Start-QemuPrep.ps1 -Accelerator tcg`; and
- authenticated SSH works.

This reduces the difference between the preparation and PANDA environment but
does not reproduce PANDA's older QEMU exactly.

## Gate D: PANDA interactive readiness

Pass criteria:

- Windows reaches a usable desktop in noVNC;
- authenticated SSH works; and
- the intended application starts and its scenario can be exercised.

Changing registers, increasing block I/O, or executing CPL3 code proves that
the guest is running. It does not prove interactive readiness.

## Gate E: snapshot and record finalization

Pass criteria:

- `savevm` creates a snapshot with nonzero VM state and no migration error;
- `end_record` completes; and
- both `<name>-rr-snp` and `<name>-rr-nondet.log` are nonempty.

A zero-byte snapshot is a hard failure. Do not attempt to treat it as a valid
recording.

## Gate F: deterministic replay and analysis

Pass criteria:

- replay reaches 100 percent without a divergence or VM-state error;
- the requested plugin loads; and
- the expected output artifact is nonempty.

`Analyze-PandaReplay.ps1` enforces nonempty recording inputs and coverage
output.

## Recorded infrastructure evidence

The originating lab retained this smoke-test evidence:

| Artifact or measurement | Result |
|---|---:|
| Recording snapshot | 291,102,175 bytes |
| Nondeterminism log | 468,553 bytes |
| Instructions recorded and replayed | 388,439,348 |
| Replay completion | 100% |
| Coverage CSV | 1,553,116 bytes |
| Coverage rows | 47,008 |
| Coverage mode | `asid-block` |

This passes Gates A, E, and F for that environment. It proves the block
snapshot, nondeterminism log, replay engine, coverage plugin, and artifact
paths.

It does **not** pass Gate D for the tested Windows 11 image. That guest reached
the desktop and SSH under modern QEMU, while the PANDA console remained at the
boot spinner and SSH did not return a banner during the final timed attempts.
The evidence points to a Windows 11/PANDA-QEMU compatibility boundary rather
than a damaged disk.

## Experiment record

For reproducible application traces, preserve:

- UTC and local start/end timestamps;
- host OS, QEMU, Docker, and PANDA versions;
- container digest;
- Git commit of this repository;
- hashes of disk seed, OVMF files, and target binaries;
- network mode and any local responder version;
- exact recording pair and plugin output; and
- a short description of user actions during recording.
