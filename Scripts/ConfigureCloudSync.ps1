param(
    [Parameter(Mandatory=$true)]
    [string]$hybridAdminUPN,
    
    [Parameter(Mandatory=$true)]
    [securestring]$hybridAdminPassword,

    [Parameter(Mandatory = $true)]
    [string]$domainAdminUPN,
    
    [Parameter(Mandatory = $true)]
    [securestring]$domainAdminPassword,

    [Parameter(Mandatory = $true)]
    [string]$domainname
)
Import-Module "C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\Microsoft.CloudSync.PowerShell.dll" 

$hybridAdminCreds = New-Object System.Management.Automation.PSCredential -ArgumentList ($hybridAdminUPN, $hybridAdminPassword) 
Connect-AADCloudSyncAzureAD -Credential $hybridAdminCreds

$domainAdminCreds = New-Object System.Management.Automation.PSCredential -ArgumentList ($domainAdminUPN, $domainAdminPassword) 

Add-AADCloudSyncGMSA -Credential $domainAdminCreds
Add-AADCloudSyncADDomain -DomainName $domainname -Credential $domainAdminCreds 

Restart-Service -Name AADConnectProvisioningAgent  
