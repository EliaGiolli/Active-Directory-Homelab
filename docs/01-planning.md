# 01 — Planning & Environment Design

Before powering on a single VM, this phase locks down the decisions that everything else depends on: topology, software sources, network design, addressing, and naming. Getting this wrong early tends to surface as confusing failures much later (DNS resolution issues, failed domain joins), so it's worth the up-front time.

## 1. Topology

Two VMs, sharing one virtual network:

- **DC01** — Windows Server, our Domain Controller. Also hosts DNS for the domain, since Active Directory depends on DNS to let clients locate domain services (via `SRV` records).
- **CL01** — Windows 10 Pro, the domain-joined client.

A single DC + single client is the minimum needed to exercise every goal of this lab (users, groups, OUs, GPOs, domain login). It can be extended later (second DC, file server, DHCP role) as stretch goals.

## 2. Software

| Component | Source | Notes |
|---|---|---|
| Windows Server 2025 Standard (Desktop Experience) | [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2025) | 180-day evaluation, free, no credit card required |
| Windows 10 Pro 22H2 | Pre-existing VM | Reused an existing VMware VM instead of downloading a fresh Windows 11 Enterprise evaluation — see rationale below |
| VMware Workstation Pro | Already installed | Free for personal use |

**Why Windows 10 Pro instead of a fresh Windows 11 Enterprise evaluation:** the domain-join capability depends on *edition*, not version — Pro, Enterprise, and Education can all join a domain; **Home cannot**. Since I already had a Windows 10 **Pro** VM on VMware, reusing it avoided an unnecessary multi-GB download and, arguably, is more realistic: in real environments you join *existing* machines to a domain far more often than freshly-imaged ones.

**Why the Evaluation Center specifically:** it's the only official, free Microsoft channel for evaluation media — no product key hunting, no untrusted mirrors. (This mattered later — see [`troubleshooting.md`](./troubleshooting.md) for a case where the wrong download link on that same page caused a non-bootable ISO.)

## 3. Networking

### Why NAT and not Bridged / Host-only

| Option | Internet access | Visible on home LAN | Verdict |
|---|---|---|---|
| Bridged (`VMnet0`) | Yes | Yes — exposes DC01 on the real network | ❌ |
| Host-only (`VMnet1`) | No | No | ❌ — no internet for licensing/updates |
| **NAT (`VMnet8`)** | **Yes** | **No** | ✅ |

NAT gives the lab VMs internet access (needed for the 180-day evaluation activation window and Windows Update) while keeping them invisible to — and isolated from — the home network.

### Configuration

- Network: `VMnet8` (VMware's default NAT network)
- Subnet: `10.10.10.0/24`
- VMware NAT gateway: `10.10.10.2` (reserved automatically by VMware, along with `10.10.10.1` for the host)
- **DHCP disabled** — addressing is fully static and assigned by hand

### Why DHCP is disabled

Two reasons:

1. **The DC must have a static IP.** It's the single most critical service in the environment — DNS, Kerberos authentication, and the `SRV` records clients rely on to find it are all tied to its address. If that address changed via DHCP, the domain would break in ways that are painful to diagnose.
2. **Avoiding the #1 AD homelab pitfall.** If VMware's own DHCP were left on, the client could receive VMware's gateway as its DNS server instead of the DC. Domain join relies on DNS queries for records like `_ldap._tcp.dc._msdcs.lab.lan`, which only the DC's DNS service knows about — a public or NAT-gateway DNS server would simply report "domain not found," and the join would fail with a misleading error. Disabling DHCP entirely removes this failure mode at the root.

### Addressing plan

| Machine | IP | Subnet | Gateway | DNS |
|---|---|---|---|---|
| VMware NAT gateway | `10.10.10.2` | /24 | — | — |
| **DC01** | `10.10.10.10` | /24 | `10.10.10.2` | `127.0.0.1` (itself) |
| **CL01** | `10.10.10.50` | /24 | `10.10.10.2` | `10.10.10.10` (the DC) |

**Why the DC's own DNS is `127.0.0.1`:** once DC01 is also running the DNS role, it must point to *itself* as primary DNS. Otherwise it can never resolve its own domain's internal records, and AD DS breaks in subtle, hard-to-diagnose ways. External name resolution (e.g. for Windows Update) is handled by DNS *forwarders* configured on the DC's own DNS server — not by pointing the DC at an external resolver directly.

**Why the client points to the DC as DNS:** a domain join isn't a ping — it's a DNS query for `SRV` records that only the domain's own DNS server can answer. Pointing the client at any other resolver (home router, `8.8.8.8`) is the most common cause of a failed domain join in any AD lab.

## 4. Domain name

Chose **`lab.lan`** over the more commonly-seen `lab.local`. `.local` is technically usable but conflicts with mDNS/Bonjour name resolution on some systems — a known real-world gotcha. `.lan` (or a subdomain of a domain you actually own) is the more modern, collision-free choice for lab/internal use.

## 5. VM specifications

| | DC01 | CL01 |
|---|---|---|
| RAM | 4 GB | 4 GB (existing VM) |
| vCPU | 2 | 4 (existing VM) |
| Disk | 60 GB, dynamically allocated | 30 GB, dynamically allocated (existing VM) |

Dynamic ("thin") disks were chosen over pre-allocated ones — actual disk usage stays well below the maximum, and there's no meaningful performance need for pre-allocation in a lab context.

## 6. Host resources

- Host RAM: 16 GB — comfortably supports both VMs running simultaneously at 4 GB each
- Free disk space needed: ~50–80 GB (accounting for both dynamic disks plus ISOs)
