# 🖥️ Active Directory Homelab — `lab.lan`

![Status](https://img.shields.io/badge/status-in%20progress-yellow)
![Platform](https://img.shields.io/badge/platform-VMware%20Workstation%20Pro-blue)
![OS](https://img.shields.io/badge/OS-Windows%20Server%202025-0078D4)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

A hands-on homelab where I built a small Active Directory environment from scratch — no templates, no automation scripts to begin with, just clicking through every screen myself and documenting what happened, including what broke along the way.

This repo is part of my learning path toward an IT Support / Junior Sysadmin role. The goal isn't just to *have* a working domain, but to understand **why** each piece is configured the way it is, and to leave a trail that someone else (or future me) can follow and learn from.

---

## 🎯 Project goals

- [x] Deploy a Windows Server VM as a Domain Controller (AD DS + DNS)
- [x] Stand up a test domain (`lab.lan`)
- [ ] Join a Windows client VM to the domain
- [ ] Design and create an OU structure (not a flat dump of users)
- [ ] Create users and groups organized by the OU structure
- [ ] Implement 2–3 realistic GPOs (password policy, drive mapping, client restriction)
- [ ] Verify end-to-end: domain user login from the client + GPO application

*(Checklist is kept up to date as the project progresses — see [Roadmap](#-roadmap--future-work) below for what's next.)*

---

## 🏗️ Architecture

| Machine | Role | OS | IP | DNS |
|---|---|---|---|---|
| **DC01** | Domain Controller / DNS Server | Windows Server 2025 Standard (Desktop Experience) | `10.10.10.10` (static) | `127.0.0.1` |
| **CL01** | Domain-joined client | Windows 10 Pro 22H2 | `10.10.10.50` (static) | `10.10.10.10` |
| Gateway | VMware NAT gateway | — | `10.10.10.2` | — |

Both VMs run on **VMware Workstation Pro**, connected through a dedicated NAT network (`VMnet8`, subnet `10.10.10.0/24`, DHCP disabled) — isolated from my home LAN but with outbound internet access for licensing activation and updates.

> 📊 A network diagram lives in [`diagrams/`](./diagrams) — see that folder's notes for what to add.

**Design decisions explained in detail in [`docs/01-planning.md`](docs/01-planning.md)**, including:
- why a NAT network instead of Bridged/Host-only
- why the DC needs a static IP
- why the client points to the DC (not a public resolver) for DNS
- why `lab.lan` instead of the more common `.local`

---

## 📁 Repository structure

```
ad-homelab/
├── README.md                      ← you are here
├── docs/
│   ├── 01-planning.md              Environment planning & network design
│   ├── 02-dc-installation.md       Building DC01: VM creation, OS install, hostname/IP config
│   ├── 03-adds-promotion.md        Installing AD DS role & promoting DC01 to a Domain Controller
│   └── troubleshooting.md          ⭐ Every issue hit so far — symptom → diagnosis → fix
├── screenshots/
│   ├── 01-planning/
│   ├── 02-dc-installation/
│   └── 03-adds-promotion/
├── scripts/                        PowerShell automation (added as the project matures)
└── diagrams/                       Network topology diagram(s)
```

---

## 🧰 Environment

- **Hypervisor:** VMware Workstation Pro (free for personal use)
- **Server OS:** Windows Server 2025 Standard Evaluation, Desktop Experience — 180-day evaluation, official Microsoft Evaluation Center
- **Client OS:** Windows 10 Pro 22H2
- **Networking:** VMware NAT (`VMnet8`), static IPs, DHCP disabled by design
- **Domain:** `lab.lan`, single forest / single domain, one Domain Controller

No cloud services, no paid licenses — the whole lab runs locally on a personal machine with 16 GB RAM.

---

## 🔍 Highlights: things that went wrong (and what they taught me)

Troubleshooting is most of the actual learning in a project like this, so it gets its own file instead of being buried in a "steps" doc. Full write-up in [`docs/troubleshooting.md`](docs/troubleshooting.md), but a few highlights:

- Spent time debugging a VM that wouldn't boot from ISO — turned out I'd downloaded the *"Languages and Optional Features ISO"* instead of the actual installer, from a different link on the same Microsoft download page.
- Renamed the server via the wrong field (`Computer description` vs. the actual `Computer name`) and only caught it by re-verifying with `hostname` in PowerShell instead of trusting the GUI at face value.
- Discovered that after installing the AD DS role, a VM snapshot revert had silently reset it — caught via `Get-WindowsFeature`, fixed by reinstalling the role directly with PowerShell (`Install-WindowsFeature`).

The pattern across all three: **verify state with a command instead of trusting what a wizard or dashboard appears to show.**

---

## 🗺️ Roadmap / Future work

This project is being built and documented incrementally. Next steps, roughly in order:

- [ ] **OU design** — plan and create an Organizational Unit structure (e.g. by department/role) instead of dumping objects into the default containers
- [ ] **Users & groups** — create domain users and security groups, organized inside the OUs above
- [ ] **Client domain join** — join the Windows 10 Pro VM to `lab.lan` and verify DNS/Kerberos resolution
- [ ] **Group Policy Objects** — implement and test:
  - a password/account lockout policy
  - a network drive mapping via GPP (Group Policy Preferences)
  - a client-side restriction (e.g. blocking Control Panel access or enforcing a desktop setting)
- [ ] **End-to-end verification** — log in as a domain user from the client and confirm GPOs apply as expected (`gpresult /r`, `gpupdate /force`)
- [ ] **PowerShell automation pass** — once the manual GUI process is understood, revisit key steps (bulk user/OU creation, GPO backup/import) as scripts in `scripts/`
- [ ] **Second Domain Controller** *(stretch goal)* — add redundancy and explore AD replication
- [ ] **DHCP role on DC01** *(stretch goal)* — replace static-only addressing for the client segment with a scoped DHCP service run by the DC, as is common in real environments

---

## 📄 License

This documentation and any accompanying scripts are released under the [MIT License](./LICENSE). Windows Server and Windows 10 are evaluation/licensed products of Microsoft Corporation and are not included in this repository.

---

## 👤 About

Built and documented by me as part of my journey toward an IT Support / Junior Sysadmin role. Feedback and suggestions are welcome — feel free to open an issue.