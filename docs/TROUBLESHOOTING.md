# Troubleshooting

| Symptom | Likely cause and action |
|---|---|
| `Unexpected VP exit code 4` under WHPX | Retry after a clean QEMU shutdown. Check for stale QEMU processes and competing virtualization/security software. If it persists, use the TCG preparation mode for diagnosis. |
| Preparation VM is dramatically slower than expected | Confirm it was started with `-Accelerator whpx`. TCG is intentionally software-emulated and single-core in compatibility mode. |
| `Cannot use 'vdi' as a backing file` or snapshot migration errors | A VDI remains in the active PANDA chain. Recreate the standalone seed by flattening the prepared qcow2 with modern host `qemu-img`. |
| PANDA creates a zero-byte `-rr-snp` | Recording snapshot failed. Verify a standalone qcow2 seed and retain `snapshot=on` for the writable raw pflash variable store. |
| `Not a migration stream` or `Failed to load vmstate` | Replay was given an invalid or empty recording snapshot. Fix the snapshot gate and make a new recording. |
| noVNC opens but Windows stays on a spinner | The VM may still be executing without becoming interactive. Inspect logs and monitor state, but do not call it ready until desktop and authenticated SSH work. |
| TCP 2222 is listening but SSH times out | QEMU's host forward is active before guest `sshd` is ready. Use `Test-GuestSsh.ps1`; wait for Windows or diagnose guest boot. |
| Guest setup fails while adding OpenSSH Server | The Windows capability source may be unavailable. Temporarily allow the guest appropriate network access or provide a Windows feature source, then rerun the idempotent bootstrap. |
| `e1000e` has no guest link | Use the repository's `e1000` device. That was the compatible device in the originating lab. |
| PANDA named CPU models stop early | Restore the augmented `qemu64` model in `container/common.sh`. Named newer models were less compatible in the tested PANDA/QEMU 2.9 build. |
| Replay diverges | Verify that live and replay use the identical container image, disk state, firmware, machine arguments, and recording pair. Never replay while the live container is running. |
| Ports are already in use | Change the loopback ports in `config/panda.psd1`. Keep them bound to `127.0.0.1`. |
| Docker mount fails for a path with spaces | Ensure the entire `--volume` value is passed as one PowerShell argument and that Docker Desktop has access to the drive. The supplied scripts already do this. |

## Logs

With `$config = Import-PowerShellDataFile .\config\panda.psd1`, inspect:

```powershell
Get-Content (Join-Path $config.WorkRoot 'logs\panda-live.log') -Tail 100
Get-Content (Join-Path $config.WorkRoot 'logs\novnc.log') -Tail 100
Get-Content (Join-Path $config.WorkRoot 'logs\ovmf-debug.log') -Tail 100
docker logs --tail 100 $config.Container
```

Monitor commands useful for distinguishing a frozen display from execution:

```powershell
.\scripts\host\Invoke-PandaMonitor.ps1 'info status'
.\scripts\host\Invoke-PandaMonitor.ps1 'info registers'
.\scripts\host\Invoke-PandaMonitor.ps1 'info blockstats'
.\scripts\host\Invoke-PandaMonitor.ps1 'info network'
```

Take samples several seconds apart. Changing instruction pointers and I/O
counters show progress, but only desktop and SSH establish interactive
readiness.
