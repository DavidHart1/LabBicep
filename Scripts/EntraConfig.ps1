param (
    [string]$ManagedIdentityClientId,
    [string]$NamePrefix,
    [securestring]$Password,
    [string]$domainName
)

Connect-Graph -Scopes -Identity -ClientId $ManagedIdentityClientId 

$PasswordProfile = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPasswordProfile
$PasswordProfile.Password = $Password
New-MgUser -DisplayName "Adele Vance" -GivenName "Adele" -Surname "Vance" -UserPrincipalName ("AdeleV@" + $domainName) -PasswordProfile $PasswordProfile -AccountEnabled $true -MailNickname "AdeleV" -Department "Sales" -JobTitle "Sales Manager" -MobilePhone "+1 206 555 0110" -OfficeLocation "18/2111" -PreferredLanguage "en-US" -StreetAddress "12345 Lake City Way NE" -City "Seattle" -State "WA" -Country "US" -PostalCode "98125"
New-MgGroup -Description "W365 Assignment Group" -DisplayName ($NamePrefix + "-W365Users") -MailEnabled $false -MailNickname ($NamePrefix + "-W365Users") -SecurityEnabled
New-MgGroup -Description "EPM Assignment Group" -DisplayName ($NamePrefix + "-EPMUsers") -MailEnabled $false -MailNickname ($NamePrefix + "-EPMUsers") -SecurityEnabled