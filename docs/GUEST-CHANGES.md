# Guest changes, side effects, and rollback

Run the generated bootstrap only in a disposable analysis clone. It makes
material security and management changes to the guest.

## Changes made

The script:

- sets `hypervisorlaunchtype off` and `vsmlaunchtype off`;
- disables guest VBS, HVCI/memory integrity, and LSA virtualization registry
  settings;
- disables guest Hyper-V, VirtualMachinePlatform, and HypervisorPlatform;
- disables automatic reboot following a crash;
- installs Windows OpenSSH Server;
- creates a local administrator named `panda` with a random, unknown password;
- installs the generated administrator SSH public key;
- disables SSH password authentication and enables public-key authentication;
- selects Windows PowerShell as the SSH default shell; and
- opens guest firewall TCP 22.

Disabling these features can affect Credential Guard, memory integrity, WSL,
Windows Sandbox, nested virtualization, and security policy compliance. Domain
or MDM policy may re-enable settings after reboot.

The host system is not modified by the guest bootstrap.

The random `panda` password is deliberately not displayed or retained because
the account is intended for key-only SSH automation. Keep an existing guest
account for desktop sign-in. Do not expect to type the `panda` password at the
Windows logon screen; reset it explicitly inside the guest if console login is
required.

## Before running it

- Make or retain a clean preparation overlay that can be discarded.
- Save the generated SSH private key under `WorkRoot\ssh`.
- Record current feature and Device Guard state if rollback matters.
- Stop the temporary Python server as soon as setup completes.

The short `irm ... | iex` command downloads executable PowerShell over an
unauthenticated lab-only HTTP endpoint. QEMU resolves `10.0.2.2` to the host
side of user networking. Use it only on the isolated preparation VM. For a
higher-assurance workflow, copy the generated `s` file through mounted media,
inspect it, and run it locally instead.

## Rollback

The cleanest rollback is to discard the preparation overlay and regenerate it
from the source VDI. That also removes the account and SSH key.

For an in-place rollback, review and selectively apply these commands in
elevated guest PowerShell:

```powershell
bcdedit.exe /set hypervisorlaunchtype auto
bcdedit.exe /set vsmlaunchtype auto

Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All -NoRestart

Set-ItemProperty `
  'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' `
  -Name AutoReboot `
  -Type DWord `
  -Value 1
```

VBS, HVCI, and LSA protection should be restored through the same security
policy mechanism that originally managed them; hard-coding registry values can
conflict with organizational policy. Reboot after restoring hypervisor
features.

If the SSH control channel should be removed:

```powershell
Remove-NetFirewallRule -Name PANDA-OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue
Remove-LocalUser -Name panda
```

Remove OpenSSH Server only if no other workflow uses it. Deleting the `panda`
account is irreversible for that account's local profile; prefer discarding
the overlay.
