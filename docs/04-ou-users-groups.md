# 04 — Organizational Units, Security Groups & Users

With DC01 promoted and `lab.lan` live, this phase builds the actual object structure inside Active Directory: an OU hierarchy, security groups, and domain users — organized by department rather than dumped into the default containers.

## 1. Why a custom OU structure

Active Directory ships with default containers (`Users`, `Computers`, etc.), but these are **containers, not true Organizational Units** — they can't have Group Policy Objects linked to them and offer no delegation boundary. Since GPOs (a later phase) apply based on position in the OU tree, and since a small "company" structure makes the whole lab more realistic, everything lives under a single root OU instead.

## 2. Structure implemented

A fictional company scenario, **"ContosoLab"**, was used to make the department split realistic rather than generic:

```
lab.lan
└── ContosoLab
    ├── Users
    │   ├── IT
    │   ├── Finance
    │   ├── Sales
    │   └── Management
    ├── Groups
    │   └── Security-Groups
    └── Computers
        └── Workstations
```

**Design notes:**
- A single root OU (`ContosoLab`) separates everything belonging to this lab from AD's built-in objects (Domain Controllers, default Users/Computers) and gives one place to link company-wide policy later.
- `Users` is split by department so future GPOs can target one department without affecting others (e.g. a stricter policy for IT, a different drive mapping for Sales).
- `Groups` and `Computers` are kept in separate branches from `Users` — GPOs that target *computer* objects (client-side restrictions) are conceptually different from GPOs targeting *user* objects (drive mappings), and separating the branches makes that distinction visible in the tree itself.
- "Protect container from accidental deletion" was left enabled on every OU — the default safety net against deleting an entire branch (and everything inside it) with a single misclick.

All OUs were created manually in **Active Directory Users and Computers** (`dsa.msc`), via right-click → **New → Organizational Unit** at each level.

## 3. Security groups

Four groups were created inside `Groups\Security-Groups`, one per department:

| Group | Scope | Type |
|---|---|---|
| `SEC-IT` | Global | Security |
| `SEC-Finance` | Global | Security |
| `SEC-Sales` | Global | Security |
| `SEC-Management` | Global | Security |

**Why Global scope:** a Global group can contain members only from the same domain, but can be granted permissions across the forest — the right fit for "grouping people together." (For reference: *Domain Local* groups are typically used to hold permissions on local resources like shared folders, and *Universal* groups are for cross-domain visibility in multi-domain forests — neither applies to a single-domain lab.)

**Why Security type, not Distribution:** Security groups can be granted permissions on resources (files, GPOs); Distribution groups exist purely for email distribution lists and carry no access-control value.

This follows the standard **"never assign permissions directly to a user"** principle: permissions/policies get attached to a group, and users are placed inside that group. Moving someone between roles later means moving group membership, not re-doing access from scratch.

## 4. Users

One user (`Marco Rossi` / `mrossi`, IT department) was created manually through the GUI to walk through the full flow before automating the rest:

1. Right-click OU → **New → User** → first/last name + logon name
2. Set a temporary password with **"User must change password at next logon"** checked (standard admin practice: the admin sets a temporary password, the user is forced to choose their own at first login)
3. Added to `SEC-IT` via the user's **Member Of** tab → **Add...**

The remaining six users were created in bulk via a PowerShell script — see [`scripts/create-user.ps1`](../scripts/create-user.ps1).

### Final user roster

| Name | Logon | Department (OU) | Group |
|---|---|---|---|
| Marco Rossi | `mrossi` | IT | `SEC-IT` |
| Anna Gialli | `agialli` | IT | `SEC-IT` |
| Laura Bianchi | `lbianchi` | Finance | `SEC-Finance` |
| Sara Ferrari | `sferrari` | Finance | `SEC-Finance` |
| Giulia Verdi | `gverdi` | Sales | `SEC-Sales` |
| Paolo Colombo | `pcolombo` | Sales | `SEC-Sales` |
| Il Direttore | `direttore` | Management | `SEC-Management` |

## 5. Automating the rest with PowerShell

`scripts/create-user.ps1` creates the remaining users and assigns each to their department's security group in one pass, instead of repeating the same GUI flow seven times.

Key techniques used:
- Users are defined as an array of hashtables (a small in-script "table" of name/logon/department/group), then a single `foreach` loop processes all of them — one process instead of duplicated code per user.
- `New-ADUser -Path <OU DistinguishedName>` creates each account directly inside the correct OU — the scripted equivalent of right-clicking the correct OU in the GUI.
- `Add-ADGroupMember` attaches each new user to their department's group — the scripted equivalent of the **Member Of → Add...** tab.
- The temporary password is passed as a `SecureString`, matching what `New-ADUser` requires (plain text isn't accepted directly).

Run with:
```powershell
cd C:\scripts
.\create-user.ps1
```

## 6. Verification

Rather than trust the ADUC GUI alone (see [`troubleshooting.md`](./troubleshooting.md#5-security-group-created-in-the-wrong-ou) for why that matters), the final structure was verified from PowerShell:

```powershell
# All users under ContosoLab\Users, with their OU path
Get-ADUser -Filter * -SearchBase "OU=Users,OU=ContosoLab,DC=lab,DC=lan" -Properties Department |
    Select Name, SamAccountName, DistinguishedName

# Every security group and its members
Get-ADGroup -Filter * -SearchBase "OU=Security-Groups,OU=Groups,OU=ContosoLab,DC=lab,DC=lan" | ForEach-Object {
    Write-Host "`n$($_.Name):" -ForegroundColor Cyan
    Get-ADGroupMember -Identity $_.Name | Select -ExpandProperty Name
}
```

Both confirmed the department → OU → group mapping is consistent end-to-end.

## 📸 Screenshots captured for this phase

- Full OU tree expanded in ADUC
- `Marco Rossi Properties → Member Of` tab showing `SEC-IT` membership
- `create-user.ps1` execution output (six "Creato: ..." lines)
- `Get-ADUser` verification output (all 7 users with their OU)
- `Get-ADGroup` + `Get-ADGroupMember` verification output (all 4 groups with members)
