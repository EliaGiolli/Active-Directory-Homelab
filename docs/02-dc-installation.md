# 02 — Building DC01: VM Creation & Windows Server Installation

This phase covers creating the DC01 virtual machine in VMware Workstation Pro, installing Windows Server 2025, and getting basic networking (hostname, static IP) correctly configured — all prerequisites before touching Active Directory itself.

## 1. VM creation (VMware Workstation Pro)

Used the **Custom (advanced)** wizard rather than **Typical**, specifically to see and control every option instead of letting VMware pick defaults silently (firmware type, network mode, etc. — all things worth understanding, not skipping).

Key choices made during the wizard:

| Setting | Value | Why |
|---|---|---|
| OS install method | *"I will install the operating system later"* | Skips VMware's "Easy Install" automation — the goal was to see and drive every installer screen manually, since this was a first-ever Windows Server install |
| Guest OS | Windows Server 2022 (closest available profile) | Windows Server 2025 wasn't listed as a guest OS option in this VMware version; 2022 is the closest match and only affects a few cosmetic defaults, not the actual OS installed |
| Firmware | UEFI | Modern standard, also required for the vTPM Windows Server needs |
| vCPU | 2 | Adequate for a lab DC |
| RAM | 4096 MB | Comfortable headroom for AD DS + DNS |
| Network | NAT (`VMnet8`) | Puts DC01 on the lab subnet designed in [planning](./01-planning.md) |
| Disk | 60 GB, single file, **not** pre-allocated | Dynamic growth keeps actual usage low (~20–25 GB in practice) |

**vTPM encryption password:** Windows Server 2025 requires a virtual TPM to install. VMware protects the vTPM support files (`.nvram`, `.vmsn`, etc.) with a password set during VM creation. This is *not* a Windows account password — it's local to VMware and unlocks powering on this specific VM. "Remember password in Credential Manager" was left checked for convenience.

## 2. Mounting the ISO & booting the installer

The ISO was mounted via **VM → Settings → CD/DVD → Use ISO image file**, with **"Connect at power on"** checked.

> ⚠️ This step hit a real, multi-stage troubleshooting issue — the ISO appeared mounted but the VM wouldn't boot from it. Full diagnosis and root cause in [`troubleshooting.md`](./troubleshooting.md#1-vm-wont-boot-from-iso-no-media--unsuccessful).

## 3. Installer choices

- **Language / keyboard:** English (US) install language, Italian keyboard layout (so physical key presses match what's typed — important for passwords)
- **Edition:** **Windows Server 2025 Standard Evaluation (Desktop Experience)**
  - *Standard* over *Datacenter*: Datacenter targets large virtualized infrastructures (unlimited guest VM licensing, software-defined storage) that a single-host lab has no use for.
  - *Desktop Experience* over *Server Core*: Core drops the GUI in favor of command-line/remote management — the right choice for production efficiency, but not for a first-time look at Server Manager, MMC consoles, etc. Core is a natural "next step" once the GUI-based concepts are solid.
- **Partitioning:** left the single 60 GB disk as unallocated space and let the installer auto-partition (EFI system partition + MSR + primary partition). Manual partitioning is only really needed with multiple physical disks or specific storage requirements — neither applies here, and hand-partitioning UEFI disks is an easy way to break booting for no benefit.

## 4. First login

VMware intercepts `Ctrl+Alt` on the host (it's the "release mouse/keyboard from the VM" shortcut), so the classic `Ctrl+Alt+Del` never reaches the guest OS. Fixed via the VMware menu: **VM → Send Ctrl+Alt+Del**, which forwards the key combination directly to the guest.

## 5. Hostname configuration

Set via **Server Manager → Local Server → Computer name → Change...**

> ⚠️ First attempt silently failed — the new name was typed into the wrong field (`Computer description`, a cosmetic label with no technical effect) instead of the actual `Computer name` field, which only appears after clicking **Change...**. Caught by verifying with `hostname` in PowerShell rather than trusting the GUI summary at face value. Full writeup in [`troubleshooting.md`](./troubleshooting.md#2-computer-name-not-changing-computer-description-vs-computer-name).

Final confirmed hostname: **`DC01`**

**Why rename before promoting to a DC:** the computer name becomes part of the Domain Controller's identity in AD and DNS once promoted. Renaming afterward is possible but awkward — better to lock it in first.

## 6. Static IP configuration

Set via **Server Manager → Local Server → [network adapter link] → adapter Properties → IPv4 Properties**:

| Field | Value |
|---|---|
| IP address | `10.10.10.10` |
| Subnet mask | `255.255.255.0` |
| Default gateway | `10.10.10.2` |
| Preferred DNS server | `127.0.0.1` |

Rationale for these values is covered in depth in [`01-planning.md`](./01-planning.md#3-networking).

Verified after reboot with:

```powershell
hostname
ipconfig /all
```

## 📸 Screenshots to capture for this phase

- VMware "New Virtual Machine" summary (Memory / Processors / Disk / Network)
- `System Properties` showing computer name `DC01`
- IPv4 properties dialog with static values filled in
- Terminal output of `hostname` and `ipconfig /all` post-reboot
