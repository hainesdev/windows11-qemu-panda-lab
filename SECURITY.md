# Security and isolation

This project is intended for software you are authorized to analyze. A VM is a
containment layer, not a guarantee of safety.

## Defaults

- The source VDI is never mounted as PANDA's writable disk.
- PANDA starts with restricted QEMU user networking unless `-Network nat` is
  explicitly selected.
- noVNC, QEMU monitor, and SSH ports are published only on `127.0.0.1`.
- The container uses `no-new-privileges` and drops all Linux capabilities.
- Replay always uses restricted networking.
- Guest SSH uses a dedicated generated key. No private key is stored here.

## Operator responsibilities

- Verify Windows and software licensing before making VM copies.
- Keep samples, secrets, recordings, and VM images outside this repository.
- Protect the generated SSH private key with host filesystem permissions.
- Do not expose the QEMU monitor or noVNC port beyond loopback.
- Use NAT only for a documented experiment; prefer a controlled local network.
- Treat packet captures and PANDA logs as potentially sensitive evidence.
- Review `docs/GUEST-CHANGES.md` before disabling guest security features; use
  a disposable clone and prefer discarding its overlay for rollback.
- Treat generated manifests as private until local paths and disk identifiers
  have been sanitized.
- Hash important inputs and preserve the exact container digest, machine
  definition, firmware, and recording pair used for an experiment.

Do not report vulnerabilities in PANDA, QEMU, Docker, or Windows to this
repository; follow each upstream project's security process.
