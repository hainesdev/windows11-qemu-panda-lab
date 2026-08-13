# Reproducibility and provenance

There are three different reproduction claims:

1. **Workflow reproduction:** another analyst can run the same conversion,
   boot, recording, and replay steps with their own compatible Windows VDI.
2. **Environment reproduction:** versions, firmware, machine arguments, and
   hashes are sufficiently recorded to rebuild a materially equivalent lab.
3. **Evidence reproduction:** the exact recording pair replays with the exact
   machine and plugin configuration that created it.

This repository provides the workflow. Environment and evidence reproduction
require artifacts generated locally because Windows disks, keys, samples, and
recordings are intentionally not public.

## Originating environment

These values are provenance for the successful experiment, not minimum
versions:

| Component | Recorded value |
|---|---|
| Host | Windows x64 build 26200 |
| Docker client/engine | 29.2.0 / 29.2.0 |
| Host QEMU | 11.0.50 (`v11.0.0-12631-g54e84cdc7a`) |
| PANDA release | 1.8.83 |
| PANDA embedded QEMU | 2.9.1, build date 2026-06-09 |
| PANDA base image | `pandare/panda@sha256:e4bb0346e9f9cd9f0b4a2f75b353cbf041005687b4af47d5705cfee054aec71b` |
| OVMF x86-64 code SHA-256 | `33090CC07675BAA5190D9F1E84BF5176B33BCBFA9BACAC522961150CDB6DBB2A` |
| OVMF variable template SHA-256 | `5D2AC383371B408398ACCEE7EC27C8C09EA5B74A0DE0CEEA6513388B15BE5D1E` |

The originating guest's exact Windows edition/build was not retained in the
public evidence. Do not invent it. Record it for every new reproduction with:

```powershell
Get-ComputerInfo -Property `
  WindowsProductName, `
  WindowsEditionId, `
  WindowsVersion, `
  OsBuildNumber, `
  OsArchitecture
```

## Generate a local manifest

After configuration and again after initialization:

```powershell
.\scripts\host\Export-LabManifest.ps1
```

For an evidence-grade manifest that hashes large VM disks:

```powershell
.\scripts\host\Export-LabManifest.ps1 -IncludeLargeFileHashes
```

Disk hashing can take a long time. The resulting JSON contains local paths and
belongs under `WorkRoot\manifests`, which is outside the repository. Sanitize
paths before sharing it publicly.

## Measure PANDA boot instead of guessing

After starting PANDA, measure authenticated SSH readiness:

```powershell
.\scripts\host\Wait-PandaGuestSsh.ps1 -TimeoutMinutes 240
```

The script writes a timestamped JSON record under `WorkRoot\logs`. The
originating guest fully booted, but earlier 12- and 20-minute observations were
premature. Its exact final time-to-desktop was not retained, so the public
documentation deliberately does not claim a fabricated number.

Record separately:

- container start to first visible Windows desktop;
- container start to authenticated SSH;
- time for the application to become usable; and
- host CPU, memory, and storage during the boot.

## Container reproducibility boundary

The PANDA base image is pinned by digest. The derived Dockerfile runs
`apt-get update` and installs noVNC, OVMF, qemu-utils, and websockify without
pinning a Debian snapshot or package versions. Therefore a later rebuild can
produce a different derived image ID even with the same PANDA base digest.

Always record the derived image ID and package state for evidence. If exact
bit-for-bit rebuilds are required, mirror or snapshot the package repository
and pin package versions in a private evidence branch. Do not assume the local
derived image ID published by one analyst is portable metadata.

## Recording compatibility set

Preserve these together:

- source/seed/active disk hashes and qcow2 backing-chain output;
- OVMF code and variable-store hashes;
- derived container image ID and PANDA/QEMU version;
- exact `container/common.sh` Git commit;
- recording snapshot and nondeterminism log;
- plugin arguments, coverage output, and replay log;
- network mode and any local service/emulator version; and
- guest build, target hash, operator actions, and timestamps.

The public numeric smoke-test results demonstrate that one such set replayed.
They are not a substitute for publishing the licensed disk and full recording,
which this repository intentionally excludes.
