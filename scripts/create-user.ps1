# create-user.ps1
# Creates the remaining ContosoLab users and adds each to their department's security group.
# Run from an elevated PowerShell session on DC01.

$domain = "lab.lan"
$ouBase = "OU=Users,OU=ContosoLab,DC=lab,DC=lan"
$defaultPassword = ConvertTo-SecureString "Contoso2026!" -AsPlainText -Force

# Each entry: First name, Last name, Logon name, Department (OU name), Security group
$users = @(
    @{First="Anna";  Last="Gialli";   Logon="agialli";  OU="IT";         Group="SEC-IT"}
    @{First="Laura"; Last="Bianchi";  Logon="lbianchi"; OU="Finance";    Group="SEC-Finance"}
    @{First="Sara";  Last="Ferrari";  Logon="sferrari"; OU="Finance";    Group="SEC-Finance"}
    @{First="Giulia";Last="Verdi";    Logon="gverdi";   OU="Sales";      Group="SEC-Sales"}
    @{First="Paolo"; Last="Colombo";  Logon="pcolombo"; OU="Sales";      Group="SEC-Sales"}
    @{First="Il";    Last="Direttore";Logon="direttore";OU="Management"; Group="SEC-Management"}
)

foreach ($u in $users) {
    $ouPath = "OU=$($u.OU),$ouBase"
    $name = "$($u.First) $($u.Last)"

    New-ADUser `
        -Name $name `
        -GivenName $u.First `
        -Surname $u.Last `
        -SamAccountName $u.Logon `
        -UserPrincipalName "$($u.Logon)@$domain" `
        -Path $ouPath `
        -AccountPassword $defaultPassword `
        -ChangePasswordAtLogon $true `
        -Enabled $true

    Add-ADGroupMember -Identity $u.Group -Members $u.Logon

    Write-Host "Creato: $name ($($u.Logon)) in $($u.OU), aggiunto a $($u.Group)"
}
