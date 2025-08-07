param (
    [Parameter(Mandatory, ParameterSetName = 'Passwords')]
    [string]$AdminUsername,

    [Parameter(Mandatory, ParameterSetName = 'Passwords')]
    [securestring]$AdminPassword,

    [Parameter(Mandatory, ParameterSetName = 'Credentials')]
    [System.Management.Automation.PSCredential]$DomainCredential,

    [Parameter(Mandatory, ParameterSetName = 'Passwords')]
    [Parameter(Mandatory, ParameterSetName = 'Credentials')]
    [securestring]$NewUserPassword,

    [Parameter(Mandatory, ParameterSetName = 'Passwords')]
    [Parameter(Mandatory, ParameterSetName = 'Credentials')]
    [string]$ManagedIdentityClientId,

    [Parameter(Mandatory, ParameterSetName = 'Passwords')]
    [Parameter(Mandatory, ParameterSetName = 'Credentials')]
    [string]$domainName
)
<#
    .DESCRIPTION
    This script sets up Active Directory (AD) by provisioning users  from Azure Active Directory.

    .PARAMETER AdminUsername
    The username of the admin account used to connect to Active Directory.

    .PARAMETER AdminPassword
    The password of the admin account used to connect to Active Directory.

    .PARAMETER NewUserPassword
    The password to set for the newly provisioned users in Active Directory.

    .PARAMETER ManagedIdentityClientId
    The client ID of the managed identity used to authenticate with Azure Active Directory.

    .PARAMETER domainName
    The name of the domain associated with the Active Directory.

    .EXAMPLE
    .\AADSetup.ps1 -AdminUsername "admin" -AdminPassword (ConvertTo-SecureString "password" -AsPlainText -Force) -NewUserPassword (ConvertTo-SecureString "newpassword" -AsPlainText -Force) -ManagedIdentityClientId "12345678-1234-1234-1234-1234567890ab" -domainName "contoso.com"
#>

# Install the Microsoft Graph (and Nuget provider) PowerShell module if it is not already installed
if (-not (Get-Module -Name Microsoft.Graph.Users -ListAvailable)) {
    if (-not (Get-PackageProvider -Name NuGet -ListAvailable)) {
        Install-PackageProvider -Name NuGet -Force
    }
    Install-Module -Name Microsoft.Graph.Users -Force
}
if (-not (Get-Module -Name Microsoft.Graph.Authentication -ListAvailable)) {
    Install-Module -Name Microsoft.Graph.Authentication -Force
}
# Import the required modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Users
Import-Module ActiveDirectory
# Connect to Azure Active Directory
if ($PSCmdlet.ParameterSetName -eq 'Passwords') {
$domainUsername = "$domainName\$AdminUsername"
$domainCredential = New-Object System.Management.Automation.PSCredential($domainUsername, $AdminPassword)
}
Connect-MgGraph -Identity -ClientId $ManagedIdentityClientId

# Download all cloud users
$cloudUsers = Get-MgUser -All | Where-Object { $_.UserPrincipalName -notlike "*onmicrosoft.com" }

# Provision users in Active Directory
$ouName = "Entra"
$domainDN = $domainName -replace "\.", ",DC="
$ouPath = "OU=$ouName,DC=$domainDN"  # Replace with your domain information
$newdomainDN = "DC=$domainDN"

# TODO: Add check to see if OU already exists, even though it shouldn't.
New-ADOrganizationalUnit -Path $newdomainDN -Name $ouName
foreach ($user in $cloudUsers) {
    $userPrincipalName = $user.UserPrincipalName
    $displayName = $user.DisplayName
    $givenName = $user.GivenName
    $surname = $user.Surname
    $mail = $user.Mail
    $samAccountName = $user.UserPrincipalName.Split("@")[0]

    $newUserParams = @{
        SamAccountName        = $samAccountName
        UserPrincipalName     = $userPrincipalName
        Name                  = $displayName
        GivenName             = $givenName
        Surname               = $surname
        EmailAddress          = $mail
        DisplayName           = $displayName
        Enabled               = $true
        Path                  = $ouPath
        Credential            = $domainCredential
        AccountPassword       = $NewUserPassword
        ChangePasswordAtLogon = $false
        PasswordNeverExpires  = $false
        PasswordNotRequired   = $false
    }
    New-ADUser @newUserParams
}
