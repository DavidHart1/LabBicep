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

# wait for internet connection to be setup.
while (-not (Test-Connection google.com -Count 1 -Quiet)) {
    Start-Sleep -Seconds 30
}

# Safely remove conflicting modules (skip core modules that can't be uninstalled)
Get-InstalledModule -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        Uninstall-Module -Name $_.Name -AllVersions -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Output "Could not uninstall module $($_.Name): $($_.Exception.Message)"
    }
}
if ((Get-Module PackageManagement -ListAvailable).Version.Minor -eq 0) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
if (-not (Get-PackageProvider -Name NuGet -ListAvailable)) {
    Install-PackageProvider -Name NuGet -Force
}
if (-not (Get-Module -Name Microsoft.Graph -ListAvailable)) {
    Install-Module -Name Microsoft.Graph.Authentication -Force
}
if (-not (Get-Module -Name Az.Accounts -ListAvailable)) {
    Install-Module -Name Az.Accounts -Force -RequiredVersion 2.13.2
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
# $ManagedIdentityClientId = '8b51a025-4422-4ec9-9e79-d7d26d7d959a'
Write-Output "Connecting to Azure with Managed Identity $ManagedIdentityClientId"
Connect-AzAccount -Identity -AccountId $ManagedIdentityClientId
# Add Key Vault
$VaultParameters = @{
    AZKVaultName = $VaultName
    SubscriptionId = $SubscriptionId
}
# Register secret vault only if not already registered (idempotent)
if (-not (Get-SecretVault -Name AZKVault -ErrorAction SilentlyContinue)) {
    Register-SecretVault -Module Az.KeyVault -Name AZKVault -VaultParameters $VaultParameters
} else {
    Write-Output "Secret vault 'AZKVault' already registered, skipping."
}
# Pull Hybrid Admin creds from Key Vault
#$AzureAdminUsername = Get-Secret -Vault AZKVault -Name $AzAdminSecretName -AsPlainText
#$AzureAdminPassword = Get-Secret -Vault AZKVault -Name $AzPassSecretName
#$AzureAdminCredential = New-Object System.Management.Automation.PSCredential($AzureAdminUsername, $AzureAdminPassword)
# Pull Domain Admin creds from Key Vault
$DomainAdminUsername = Get-Secret -Vault AZKVault -Name $DomainAdminSecretName -AsPlainText
$DomainAdminPassword = Get-Secret -Vault AZKVault -Name $DomainPassSecretName
$DomainAdminCredential = [PSCredential]::New($DomainAdminUsername, $DomainAdminPassword)

$DomainUserPassword = Get-Secret -Vault AZKVault -Name $DomainUserSecretName
# Call AADSetup.ps1 with proper creds, using secureStrings
.\AADSetup.ps1 -DomainCredential $DomainAdminCredential -NewUserPassword $DomainUserPassword -ManagedIdentityClientId $ManagedIdentityClientId -domainName $DomainName
# Call ConfigureCloudSync.ps1 with proper creds, using secureStrings
$accesstoken = get-azaccesstoken
.\ConfigureCloudSync.ps1 -AccessToken $accesstoken.token -TenantId $accesstoken.tenantid -UserId $accesstoken.UserId -domainAdminCreds $DomainAdminCredential -domainname $DomainName
#.\ConfigureCloudSync.ps1 -hybridAdminCreds $AzureAdminCredential -domainAdminCreds $DomainAdminCredential -domainname $DomainName