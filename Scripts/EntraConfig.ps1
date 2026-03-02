param (
    [string]$ManagedIdentityClientId,
    [string]$NamePrefix,
    [securestring]$Password,
    [string]$domainName
)

# Install the Microsoft Graph (and Nuget provider) PowerShell module if it is not already installed
if (-not (Get-Module -Name Microsoft.Graph.Users -ListAvailable)) {
    if (-not (Get-PackageProvider -Name NuGet -ListAvailable)) {
        Install-PackageProvider -Name NuGet -Force
    }
    Install-Module -Name Microsoft.Graph.Users -Force
}
if (-not (Get-Module -Name Microsoft.Graph.Identity.DirectoryManagement -ListAvailable)) {
    Install-Module -Name Microsoft.Graph.Identity.DirectoryManagement -Force
}
if (-not (Get-Module -Name Microsoft.Graph.Authentication -ListAvailable)) {
    Install-Module -Name Microsoft.Graph.Authentication -Force
}
if (-not (Get-Module -Name Microsoft.Graph.Groups -ListAvailable)) {
    Install-Module -Name Microsoft.Graph.Groups -Force
}

Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Identity.DirectoryManagement

Connect-MgGraph -Identity -ClientId $ManagedIdentityClientId

$PasswordProfile = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPasswordProfile
$PasswordProfile.Password = $env:Password
$PasswordProfile.ForceChangePasswordNextSignIn = $false
$PasswordProfile.ForceChangePasswordNextSignInWithMfa = $false

# Create or update users (idempotent)
$usersToCreate = @(
    @{
        DisplayName = "Adele Vance"; GivenName = "Adele"; Surname = "Vance"; UPN = "AdeleV@$domainName"; MailNickname = "AdeleV"
        Department = "Sales"; JobTitle = "Sales Manager"; MobilePhone = "+1 206 555 0110"; OfficeLocation = "18/2111"
        PreferredLanguage = "en-US"; StreetAddress = "12345 Lake City Way NE"; City = "Seattle"; State = "WA"; Country = "US"; PostalCode = "98125"
    },
    @{
        DisplayName = "Kelly Dixon"; GivenName = "Kelly"; Surname = "Dixon"; UPN = "KellyD@$domainName"; MailNickname = "KellyD"
        Department = "Psychology"; JobTitle = "Psychologist"; MobilePhone = "+1 206 555 0110"; OfficeLocation = "18/2112"
        PreferredLanguage = "en-US"; StreetAddress = "12345 Lake City Way NE"; City = "Seattle"; State = "WA"; Country = "US"; PostalCode = "98125"
    },
    @{
        DisplayName = "David Hart (non-admin)"; GivenName = "David"; Surname = "Hart"; UPN = "DavidH@$domainName"; MailNickname = "DavidH"
        Department = "Sales"; JobTitle = "Solutions Engineer"; MobilePhone = "+1 206 555 0110"; OfficeLocation = "18/2113"
        PreferredLanguage = "en-US"; StreetAddress = "12345 Lake City Way NE"; City = "Seattle"; State = "WA"; Country = "US"; PostalCode = "98125"
    }
)

foreach ($u in $usersToCreate) {
    $existing = Get-MgUser -Filter "userPrincipalName eq '$($u.UPN)'" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Output "User $($u.UPN) already exists, updating..."
        Update-MgUser -UserId $existing.Id -DisplayName $u.DisplayName -GivenName $u.GivenName -Surname $u.Surname `
            -Department $u.Department -JobTitle $u.JobTitle -MobilePhone $u.MobilePhone -OfficeLocation $u.OfficeLocation `
            -PreferredLanguage $u.PreferredLanguage -StreetAddress $u.StreetAddress -City $u.City -State $u.State `
            -Country $u.Country -PostalCode $u.PostalCode
    } else {
        Write-Output "Creating user $($u.UPN)..."
        New-MgUser -DisplayName $u.DisplayName -GivenName $u.GivenName -Surname $u.Surname `
            -UserPrincipalName $u.UPN -PasswordProfile $PasswordProfile -AccountEnabled `
            -MailNickname $u.MailNickname -Department $u.Department -JobTitle $u.JobTitle `
            -MobilePhone $u.MobilePhone -OfficeLocation $u.OfficeLocation -PreferredLanguage $u.PreferredLanguage `
            -StreetAddress $u.StreetAddress -City $u.City -State $u.State -Country $u.Country -PostalCode $u.PostalCode
    }
}

# Create groups if they don't already exist (idempotent)
$groupsToCreate = @(
    @{ Description = "W365 Assignment Group"; DisplayName = "$NamePrefix-W365Users"; MailNickname = "$NamePrefix-W365Users" },
    @{ Description = "EPM Assignment Group"; DisplayName = "$NamePrefix-EPMUsers"; MailNickname = "$NamePrefix-EPMUsers" }
)

foreach ($g in $groupsToCreate) {
    $existingGroup = Get-MgGroup -Filter "displayName eq '$($g.DisplayName)'" -ErrorAction SilentlyContinue
    if ($existingGroup) {
        Write-Output "Group $($g.DisplayName) already exists, skipping."
    } else {
        Write-Output "Creating group $($g.DisplayName)..."
        New-MgGroup -Description $g.Description -DisplayName $g.DisplayName -MailEnabled:$false -MailNickname $g.MailNickname -SecurityEnabled
    }
}