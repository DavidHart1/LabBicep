# Parameters
param(
    [Parameter(Mandatory = $true)]
    [string]$ManagedIdentityClientId,
    [Parameter(Mandatory = $true)]
    [string]$VaultName,
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    [Parameter(Mandatory = $true)]
    [string]$AzAdminSecretName,
    [Parameter(Mandatory = $true)]
    [string]$AzPassSecretName,
    [Parameter(Mandatory = $true)]
    [string]$DomainAdminSecretName,
    [Parameter(Mandatory = $true)]
    [string]$DomainPassSecretName,
    [Parameter(Mandatory = $true)]
    [string]$DomainName,
    [Parameter(Mandatory = $true)]
    [string]$DomainUserSecretName

)
# Might have to do some kind of network check here if the DNS Forwarding change doesn't fix this.
# Install the Microsoft Graph and Az (and Nuget provider) PowerShell module if it is not already installed
if ((get-module PackageManagement -ListAvailable).version.minor -eq 0) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
if (-not (Get-PackageProvider -Name NuGet -ListAvailable)) {
    Install-PackageProvider -Name NuGet -Force
}
if (-not (Get-Module -Name Microsoft.Graph -ListAvailable)) {
    Install-Module -Name Microsoft.Graph -Force
}
if (-not (Get-Module -Name Az.Accounts -ListAvailable)) {
    Install-Module -Name Az.Accounts -Force
}
if (-not (Get-Module -Name Az.KeyVault -ListAvailable)) {
    Install-Module -Name Az.KeyVault -Force
}
if (-not (Get-Module -Name Microsoft.PowerShell.SecretManagement -ListAvailable)) {
    Install-Module -Name Microsoft.PowerShell.SecretManagement -Repository PSGallery -Force
}
# Import Required Modules
Import-Module Microsoft.Graph.Authentication
Import-Module Az.Accounts
Import-Module Az.KeyVault
Import-Module Microsoft.PowerShell.SecretManagement
# Connect to Azure
Connect-AzAccount -Identity -AccountId $ManagedIdentityClientId
# Add Key Vault
$VaultParameters = @{
    AZKVaultName = $VaultName
    SubscriptionId = $SubscriptionId
}
Register-SecretVault -Module Az.KeyVault -Name AZKVault -VaultParameters $VaultParameters
# Pull Hybrid Admin creds from Key Vault
#$AzureAdminUsername = Get-Secret -Vault AZKVault -Name $AzAdminSecretName -AsPlainText
#$AzureAdminPassword = Get-Secret -Vault AZKVault -Name $AzPassSecretName
#$AzureAdminCredential = New-Object System.Management.Automation.PSCredential($AzureAdminUsername, $AzureAdminPassword)
# Pull Domain Admin creds from Key Vault
$DomainAdminUsername = Get-Secret -Vault AZKVault -Name $DomainAdminSecretName -AsPlainText
$DomainAdminPassword = Get-Secret -Vault AZKVault -Name $DomainPassSecretName
$DomainAdminCredential = New-Object System.Management.Automation.PSCredential($DomainAdminUsername, $DomainAdminPassword)

$DomainUserPassword = Get-Secret -Vault AZKVault -Name $DomainUserSecretName
# Call AADSetup.ps1 with proper creds, using secureStrings
.\AADSetup.ps1 -DomainCredential $DomainAdminCredential -NewUserPassword $DomainUserPassword -ManagedIdentityClientId $ManagedIdentityClientId -domainName $DomainName
# Call ConfigureCloudSync.ps1 with proper creds, using secureStrings
$accesstoken = get-azaccesstoken
.\ConfigureCloudSync.ps1 -AccessToken $accesstoken.token -TenantId $accesstoken.tenantid -UserId $accesstoken.UserId -domainAdminCreds $DomainAdminCredential -domainname $DomainName
#.\ConfigureCloudSync.ps1 -hybridAdminCreds $AzureAdminCredential -domainAdminCreds $DomainAdminCredential -domainname $DomainName