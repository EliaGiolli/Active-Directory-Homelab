# Troubleshooting Log

The most valuable part of building this lab wasn't the happy-path clicks — it was diagnosing the handful of things that didn't work the first time. This file logs every issue hit so far in a consistent format: **symptom → diagnosis steps → root cause → fix → lesson**.

This log will keep growing as the project continues (client join, GPOs, etc. are likely to produce more entries).

---

## 1. VM won't boot from ISO ("No Media" → "unsuccessful")

**Symptom:** Powering on DC01 dropped straight to the UEFI firmware boot log instead of launching the Windows Setup installer.

**Diagnosis:**
1. First boot log showed:
   ```
   EFI VMware Virtual NVME Namespace (NSID 1)... No Media.
   EFI VMware Virtual SATA CDROM Drive (1.0)... No Media.
   EFI Network...
   ```
   `No Media` on the CD-ROM entry meant the firmware saw the virtual drive but nothing was mounted in it.
2. Checked **VM → Settings → CD/DVD**: ISO path was set and "Connect at power on" was checked — looked correct on paper.
3. Did a full **Power Off → Power On** (not "Restart Guest" — a restart signal sent to a guest with no OS loaded yet does nothing, since there's no OS to catch the ACPI signal).
4. Second attempt produced a *different* message:
   ```
   EFI VMware Virtual SATA CDROM Drive (1.0)... unsuccessful.
   ```
   This is a meaningfully different symptom: the drive now had *something* mounted, but the firmware couldn't boot from it — pointing at the ISO's contents, not the mount configuration.
5. Manually selecting the CD-ROM entry from the UEFI **Boot Manager** menu and confirming with Enter still failed — ruling out a boot-order/timing issue entirely.

**Root cause:** the downloaded file was not actually the Windows Server installer. On the Microsoft Evaluation Center download page, there are two similarly-placed links: **"Download the ISO"** (the actual installer) and **"Languages and Optional Features ISO"** (a supplementary ISO containing only language packs — no bootable OS at all). The latter had been downloaded by mistake.

**Fix:** identified the correct "Download the ISO" link on the same page, downloaded the real installer (~5–6 GB, filename pattern like `SERVER_EVAL_x64FRE_en-us.iso`), remounted it, and the installer booted normally on the first try.

**Lesson:** a "No Media" vs. "unsuccessful" distinction in a UEFI boot log is diagnostically meaningful — the first points at mount configuration, the second at the mounted file's actual content. Also: download pages with multiple similarly-worded links are worth double-checking by filename/size before assuming the right file was grabbed.

---

## 2. Computer name not changing (`Computer description` vs. `Computer name`)

**Symptom:** After going through System Properties to rename the server to `DC01` and rebooting, `hostname` in PowerShell still returned the original auto-generated name (`WIN-XXXXXXXXX`).

**Diagnosis:**
1. Re-opened **System Properties** (`sysdm.cpl`) to check current state.
2. Found `DC01` had in fact been typed — but into the **"Computer description"** field on the main "Computer Name" tab, which is purely a cosmetic label with zero technical effect (not read by AD, DNS, or anything else).
3. The **actual** rename field only appears in a separate dialog, reached via the **"Change..."** button — and that dialog still showed the original `Full computer name`.

**Root cause:** two visually adjacent but functionally unrelated fields in the same tab — one cosmetic, one authoritative — with no obvious visual distinction pointing to which is which.

**Fix:** clicked **Change...**, entered `DC01` in the correct `Computer name` field this time, confirmed through the "restart required" prompt, and chose **Restart Now** (rather than "Restart Later", to remove any doubt about whether the change had actually been applied before the next reboot).

**Lesson:** verify configuration changes with a command (`hostname`) rather than trusting a GUI summary screen — the GUI didn't show an error, it just silently reflected a change that had gone to the wrong field.

---

## 3. "Next" button disabled in Add Roles and Features wizard

**Symptom:** On the **Select Features** screen of the *Add Roles and Features* wizard, the **Next** button appeared and stayed visually disabled (greyed out) no matter what was clicked.

**Diagnosis:**
1. Ruled out a focus/input issue (a recurring theme with VMware's mouse/keyboard capture) — the button was genuinely disabled, not just unresponsive to clicks.
2. Noticed a feature entry, **".NET Framework 4.8 Features (2 of 7 installed)"**, showing a partial/indeterminate checkbox state rather than a clean checked or unchecked box.
3. Scrolled the (~40-item) features list further and found a checkbox further down that had been left in an indeterminate state, invisible without scrolling.

**Root cause:** a checked/partially-checked feature further down the list, hidden by the default scroll position, was keeping the wizard's validation from completing.

**Fix:** scrolled the full list, found and resolved the stray checkbox, and "Next" became clickable immediately.

**Lesson:** wizard forms with long scrollable lists can have state issues that aren't visible in the initially-rendered viewport — when a "supposed to be enabled" control isn't, scroll the whole form before assuming something is broken.

---

## 4. AD DS role missing after a snapshot revert

**Symptom:** Returned to Server Manager expecting the previously-installed AD DS role, but the dashboard showed only **"File and Storage Services"** under Roles and Server Groups (`Roles: 1`) — no AD DS, and no pending-restart notification flag either.

**Diagnosis:**
1. Rather than trust the dashboard (which can be slow to refresh), verified directly with:
   ```powershell
   Get-WindowsFeature -Name AD-Domain-Services
   ```
   Output confirmed `Install State: Available` — i.e., genuinely not installed, not just a stale UI.
2. Most likely cause: a VM snapshot had been reverted to a point before the role was installed (a hazard of using snapshots liberally as safety checkpoints without labeling them clearly).

**Fix:** reinstalled the role directly via PowerShell instead of re-running the full GUI wizard:
```powershell
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
```
Re-verified with the same `Get-WindowsFeature` command, now showing `Installed`.

**Lesson:** snapshots are a safety net, but only if you know exactly which one you're on — from now on, snapshots are named with enough context (e.g. `02b - AD DS role installed (confirmed via PowerShell)`) and taken *immediately after* command-line-verified milestones, not just after a wizard reports success.

---

## 5. Security group created in the wrong OU

**Symptom:** After creating `SEC-IT` and `SEC-Sales` successfully inside `Groups\Security-Groups`, attempting to create `SEC-Finance` and `SEC-Management` the same way appeared to do nothing — the new groups weren't visible in the `Security-Groups` OU. Re-attempting to create them produced an "object already exists" error.

**Diagnosis:**
1. The "already exists" error was the key clue: the groups **had** been created — they just weren't where expected.
2. Selecting the parent `Groups` OU (one level up) instead of `Security-Groups` revealed `SEC-Finance` and `SEC-Management` sitting directly inside it, alongside the `Security-Groups` OU itself as a sibling object.
3. Root cause: **New → Group** had been triggered from a right-click on `Groups` instead of `Security-Groups` — an easy mistake in a deeply nested tree with visually similar row heights.

**Fix:** used **right-click → Move...** on each misplaced group to relocate it into `Security-Groups`, rather than deleting and recreating them. Verified the final state independent of the GUI:
```powershell
Get-ADGroup -Filter * -SearchBase "OU=Security-Groups,OU=Groups,OU=ContosoLab,DC=lab,DC=lan" | Select Name
```
which returned all four expected groups.

**Lesson:** in a nested OU tree, always double-check which node is actually selected/highlighted before right-clicking "New" — and when an object "seems missing" after creation, check one level up in the tree before assuming it wasn't created at all.

---

## 6. VMware Tools installed but clipboard sharing doesn't work

**Symptom:** Copy-paste between the host PC and the DC01 VM didn't work, blocking an easy way to transfer a PowerShell script into the guest.

**Diagnosis:**
1. Checked **VM → Settings → Options → Guest Isolation**: "Enable copy and paste" and "Enable drag and drop" were checked, but greyed out / non-interactive — a strong signal that VMware itself considers VMware Tools not properly running, regardless of what was "installed" before.
2. Verified directly from the guest:
   ```powershell
   Get-Service VMTools
   ```
   returned **"Cannot find any service with service name 'VMTools'"** — proof the service didn't exist at all, meaning VMware Tools was never actually fully installed, despite an earlier attempt.
3. Checked the VM's right-click menu on the host side: it showed **"Cancel VMware Tools Installation"** rather than "Install VMware Tools" — meaning the installer ISO was already mounted inside the guest from a prior attempt, but the setup executable inside it had never actually been run to completion.
4. Located the mounted VMware Tools virtual CD-ROM inside the guest (via File Explorer) — modern 64-bit-only Tools packages ship with a single `setup.exe` (no more separate `setup32.exe`/`setup64.exe`), which wasn't the file initially expected.

**Fix:** ran `setup.exe` from the mounted CD-ROM drive **as Administrator** from inside the guest, completed the full installation wizard, and rebooted. `Get-Service VMTools` then returned `Status: Running`, and clipboard sharing started working immediately.

**Lesson:** "VM → Install VMware Tools" from the host only *mounts the installer ISO* inside the guest — it does not run the installation. The actual `setup.exe` must be executed manually, with administrator privileges, from inside the guest OS for the installation to actually take effect.

---

## Pattern across all issues

Nearly every one of these was ultimately caught by **verifying actual system state with a command** (`hostname`, `ipconfig`, `Get-WindowsFeature`, `Get-Service`, `Get-ADGroup`, the UEFI boot log itself) rather than trusting a GUI's summary at face value. That's probably the single biggest practical takeaway from this project so far.
