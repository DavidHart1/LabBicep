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
# TODO: Add some error checking here to still succeed even if the users already exist. Maybe do an update-mguser if they do.

New-MgUser -DisplayName "Adele Vance" -GivenName "Adele" -Surname "Vance" -UserPrincipalName ("AdeleV@" + $domainName) -PasswordProfile $PasswordProfile -AccountEnabled -MailNickname "AdeleV" -Department "Sales" -JobTitle "Sales Manager" -MobilePhone "+1 206 555 0110" -OfficeLocation "18/2111" -PreferredLanguage "en-US" -StreetAddress "12345 Lake City Way NE" -City "Seattle" -State "WA" -Country "US" -PostalCode "98125"
New-MgUser -DisplayName "Kelly Dixon" -GivenName "Kelly" -Surname "Dixon" -UserPrincipalName ("KellyD@" + $domainName) -PasswordProfile $PasswordProfile -AccountEnabled -MailNickname "KellyD" -Department "Psychology" -JobTitle "Psychologist" -MobilePhone "+1 206 555 0110" -OfficeLocation "18/2112" -PreferredLanguage "en-US" -StreetAddress "12345 Lake City Way NE" -City "Seattle" -State "WA" -Country "US" -PostalCode "98125"
New-MgUser -DisplayName "David Hart (non-admin)" -GivenName "David" -Surname "Hart" -UserPrincipalName ("DavidH@" + $domainName) -PasswordProfile $PasswordProfile -AccountEnabled -MailNickname "DavidH" -Department "Sales" -JobTitle "Solutions Engineer" -MobilePhone "+1 206 555 0110" -OfficeLocation "18/2113" -PreferredLanguage "en-US" -StreetAddress "12345 Lake City Way NE" -City "Seattle" -State "WA" -Country "US" -PostalCode "98125"
New-MgGroup -Description "W365 Assignment Group" -DisplayName ($NamePrefix + "-W365Users") -MailEnabled:$false -MailNickname ($NamePrefix + "-W365Users") -SecurityEnabled
New-MgGroup -Description "EPM Assignment Group" -DisplayName ($NamePrefix + "-EPMUsers") -MailEnabled:$false -MailNickname ($NamePrefix + "-EPMUsers") -SecurityEnabled