# Troubleshooting

| Symptom | Likely cause and action |
|---|---|
| Windows installer says the PC cannot run Windows 11 | This repository does not provide the ISO-install machine, TPM 2.0, or Secure Boot workflow. Start from a supported, already-installed UEFI VDI as documented in `SOURCE-VM.md`. |
| Guest asks for a BitLocker recovery key | The virtual TPM/firmware identity changed. Use the recovery key retained before cloning; do not treat the prompt as PANDA corruption. Prepare a decrypted or protector-suspended lab clone if appropriate. |
| Guest enters the UEFI shell or reports no boot device | Confirm the source is GPT/UEFI, the current VirtualBox state was consolidated into the VDI, and the IDE disk is present. A saved-state or base-only snapshot VDI is not a complete source. |
| `Unexpected VP exit code 4` under WHPX | Retry after a clean QEMU shutdown. Check for stale QEMU processes and competing virtualization/security software. If it persists, use the TCG preparation mode for diagnosis. |
| WHPX accelerator is unavailable | Enable CPU virtualization in host firmware and the Windows Hypervisor Platform feature, then reboot. Do not disable the host hypervisor required by Docker/WHPX; the guest bootstrap changes only the guest. |
| Preparation VM is dramatically slower than expected | Confirm it was started with `-Accelerator whpx`. TCG is intentionally software-emulated and single-core in compatibility mode. |
| `Cannot use 'vdi' as a backing file` or snapshot migration errors | A VDI remains in the active PANDA chain. Recreate the standalone seed by flattening the prepared qcow2 with modern host `qemu-img`. |
| PANDA creates a zero-byte `-rr-snp` | Recording snapshot failed. Verify a standalone qcow2 seed and retain `snapshot=on` for the writable raw pflash variable store. |
| `Not a migration stream` or `Failed to load vmstate` | Replay was given an invalid or empty recording snapshot. Fix the snapshot gate and make a new recording. |
| noVNC opens but Windows stays on a spinner | PANDA can take far longer than modern QEMU to boot Windows 11. Compare register and block-I/O samples over time. If execution and I/O continue, keep waiting; the originating guest fully booted only after earlier 12- and 20-minute checks had already been judged too slow. |
| TCP 2222 is listening but SSH times out | QEMU's host forward is active before guest `sshd` is ready. Use `Test-GuestSsh.ps1`; wait for Windows or diagnose guest boot. |
| SSH reports `REMOTE HOST IDENTIFICATION HAS CHANGED` | A different overlay generated a new guest SSH host key while reusing host port 2222. Verify that the change is expected, then remove only that endpoint from the configured `known_hosts` with `ssh-keygen -R '[127.0.0.1]:2222' -f <known_hosts_path>`. Never disable host-key checking globally. |
| Guest setup fails while adding OpenSSH Server | The Windows capability source may be unavailable. Temporarily allow the guest appropriate network access or provide a Windows feature source, then rerun the idempotent bootstrap. |
| `irm http://10.0.2.2:8000/s` cannot connect | Confirm the Python server is still running, is bound to `0.0.0.0`, and the host firewall permits the temporary listener. Stop the server immediately after setup. Alternatively copy the generated `s` file into the guest and inspect/run it locally. |
| `e1000e` has no guest link | Use the repository's `e1000` device. That was the compatible device in the originating lab. |
| PANDA named CPU models stop early | Restore the augmented `qemu64` model in `container/common.sh`. Named newer models were less compatible in the tested PANDA/QEMU 2.9 build. |
| Replay diverges | Verify that live and replay use the identical container image, disk state, firmware, machine arguments, and recording pair. Never replay while the live container is running. |
| Ports are already in use | Change the loopback ports in `config/panda.psd1`. Keep them bound to `127.0.0.1`. |
| Docker mount fails for a path with spaces | Ensure the entire `--volume` value is passed as one PowerShell argument and that Docker Desktop has access to the drive. The supplied scripts already do this. |
| `root` snapshot does not exist | Complete the PANDA boot, make the guest idle, and run `Save-PandaSnapshot.ps1 -Name root`. It is intentionally not created automatically. |
| `active-recording.json` already exists | A prior recording was not finalized. Inspect PANDA/replay logs and the two recording files. Do not delete the marker while a recording may still be active. Move it aside only during stopped-VM recovery. |
| Guest changes made after `Initialize-Panda.ps1` do not appear | Initialization preserves an existing standalone seed and active overlay. Shut down all users, archive both PANDA disks as an evidence set, move them aside, and rerun initialization to flatten the updated preparation overlay. |
| QEMU command fails but the GUI build shows no error | Temporarily set `QemuSystem` to `qemu-system-x86_64.exe` instead of the `w.exe` GUI build so stderr is visible. |
| Offline mode has no Internet access | Expected. `restrict=on` blocks guest-initiated external connections while retaining the explicit host-to-guest SSH forward. Select NAT only for a documented experiment. |
| Target exits with an illegal-instruction exception | PANDA presents the augmented `qemu64` CPU, not the WHPX host CPU. Check whether the application requires AVX, AVX2, or another absent instruction set before changing the shared live/replay CPU definition. Any CPU change invalidates compatibility with earlier recordings. |

## Logs

With `$config = Import-PowerShellDataFile .\config\panda.psd1`, inspect:

```powershell
Get-Content (Join-Path $config.WorkRoot 'logs\panda-live.log') -Tail 100
Get-Content (Join-Path $config.WorkRoot 'logs\novnc.log') -Tail 100
Get-Content (Join-Path $config.WorkRoot 'logs\ovmf-debug.log') -Tail 100
docker logs --tail 100 $config.Container
```

`docker logs` is available only while the `--rm` live container still exists.
PANDA, OVMF, and noVNC file logs remain under `WorkRoot\logs` after container
exit.

Monitor commands useful for distinguishing a frozen display from execution:

```powershell
.\scripts\host\Invoke-PandaMonitor.ps1 'info status'
.\scripts\host\Invoke-PandaMonitor.ps1 'info registers'
.\scripts\host\Invoke-PandaMonitor.ps1 'info blockstats'
.\scripts\host\Invoke-PandaMonitor.ps1 'info network'
```

Take samples several seconds apart. Changing instruction pointers and I/O
counters show progress and justify a longer wait. The desktop establishes boot
completion; authenticated SSH and the target scenario establish application
readiness.
