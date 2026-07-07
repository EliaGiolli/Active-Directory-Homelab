# 03 — Installing AD DS & Promoting DC01 to a Domain Controller

This is the phase where `lab.lan` actually comes into existence. It's split into two genuinely distinct steps that are easy to conflate as one:

1. **Installing the AD DS role** — putting the software on the server (like installing any other Windows feature)
2. **Promoting the server** — configuring and activating it as an actual Domain Controller (creating the AD database, defining the forest/domain, configuring DNS)

## 1. Installing the AD DS role

Initially installed via **Server Manager → Manage → Add Roles and Features**, selecting **Active Directory Domain Services** and accepting the bundled management tools (RSAT consoles, AD PowerShell module) via the "Add Features" prompt.

> ⚠️ Hit a blocked/greyed-out "Next" button on the **Select Features** screen during this wizard — turned out to be a partially-checked feature hidden by the list's scroll position. See [`troubleshooting.md`](./troubleshooting.md#3-next-button-disabled-in-add-roles-and-features-wizard).

> ⚠️ **Bigger issue:** after completing this step and later returning to Server Manager, the AD DS role was no longer showing as installed at all (`Roles: 1` — only *File and Storage Services*, no AD DS). Root-caused with `Get-WindowsFeature`, most likely caused by reverting to an earlier VM snapshot. Fixed by reinstalling directly via PowerShell rather than repeating the whole GUI wizard:

```powershell
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
```

Verified with:

```powershell
Get-WindowsFeature -Name AD-Domain-Services
```

confirming `Install State: Installed`. Full writeup in [`troubleshooting.md`](./troubleshooting.md#4-ad-ds-role-missing-after-a-snapshot-revert).

**Lesson for the rest of the lab:** take a fresh snapshot immediately *after* confirming a state via command-line verification — not just after a wizard claims success — to avoid losing work to a stale snapshot revert again.

## 2. Promoting DC01 to a Domain Controller

Promoted using PowerShell instead of the Server Manager GUI wizard, as an early step toward the "automate what you already understand" approach:

```powershell
Install-ADDSForest -DomainName "lab.lan"
```

This is the PowerShell equivalent of the GUI wizard's **"Add a new forest"** deployment option (as opposed to *"add a domain controller to an existing domain"* or *"add a new domain to an existing forest"* — neither applies here, since no domain or forest exists yet).

### Key concepts / choices involved

- **Forest** — the top-level AD container; can hold one or more domains. This lab uses a single forest containing a single domain — the simplest and most common topology for a lab or small business.
- **Domain** — the administrative boundary containing users, computers, and policies. Ours: `lab.lan`.
- **Forest/Domain functional level** — left at the highest available (Windows Server 2025), since there's only one DC in this environment and no legacy DC to maintain compatibility with. In a real multi-DC environment, this level is constrained by the oldest DC still in service.
- **DNS Server role** — installed alongside AD DS automatically (this is the standard "all-in-one" DC pattern). A warning about DNS delegation not being creatable is expected and harmless in a lab — it only means there's no parent DNS zone on the public internet delegating to `lab.lan`, which isn't needed here.
- **Global Catalog** — enabled automatically; required for the first DC in a forest regardless.
- **`SafeModeAdministratorPassword` (DSRM password)** — set when prompted. This is the **Directory Services Restore Mode** password: a separate, independent credential used only for AD disaster-recovery scenarios (e.g. restoring a corrupted AD database), *not* the domain Administrator password used day to day. Windows never displays it again once set, so it was recorded alongside other lab credentials immediately.

The command prompts for confirmation before proceeding, since it warns that **the server will restart automatically** once the operation completes:

```
The target server will be configured as a domain controller and restarted when this operation is complete.
Do you want to continue with this operation?
[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"):
```

Confirmed with `Y`. The server rebooted automatically once the operation completed.

## 3. Post-promotion verification

After the automatic reboot, login now requires the domain-qualified account (`LAB\Administrator` rather than the previous local `Administrator`), which is itself a first confirmation that the domain now exists.

Verified more rigorously via PowerShell:

```powershell
Get-ADDomain
```

Returned domain details (`DNSRoot: lab.lan`, `NetBIOSName: LAB`, etc.), confirming the domain is live.

```powershell
Get-Service DNS, NTDS, Netlogon
```

Confirms the three core services backing a Domain Controller are running:

| Service | Role |
|---|---|
| `DNS` | DNS Server — resolves internal AD records and (via forwarders) external names |
| `NTDS` | NT Directory Services — the actual AD database engine |
| `Netlogon` | Authentication and DC location services used by clients |

## 📸 Screenshots to capture for this phase

- `Get-WindowsFeature -Name AD-Domain-Services` showing `Installed`
- The `Install-ADDSForest` confirmation prompt
- `Get-ADDomain` output
- `Get-Service DNS, NTDS, Netlogon` output, all `Running`
