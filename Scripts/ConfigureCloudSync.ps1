[CmdletBinding(DefaultParameterSetName = 'Credentials')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Passwords')]
    [string]$hybridAdminUPN,
    
    [Parameter(Mandatory, ParameterSetName = 'Passwords')]
    [securestring]$hybridAdminPassword,

    [Parameter(Mandatory, ParameterSetName = 'Passwords')]
    [string]$domainAdminUPN,
    
    [Parameter(Mandatory, ParameterSetName = 'Passwords')]
    [securestring]$domainAdminPassword,

    [Parameter(Mandatory, ParameterSetName = 'Credentials')]
    [System.Management.Automation.PSCredential]$hybridAdminCreds,
    # Maybe change this to a PSObject for the token info?
    [Parameter(Mandatory, ParameterSetName = 'CredentialAndToken')]
    [string]$accessToken,
    
    [Parameter(Mandatory, ParameterSetName = 'CredentialAndToken')]
    [string]$tenantId,
    
    [Parameter(Mandatory, ParameterSetName = 'CredentialAndToken')]
    [string]$userId,

    [Parameter(Mandatory, ParameterSetName = 'Credentials')]
    [Parameter(Mandatory, ParameterSetName = 'CredentialAndToken')]
    [System.Management.Automation.PSCredential]$domainAdminCreds,

    [Parameter(Mandatory, ParameterSetName = 'Passwords')]
    [Parameter(Mandatory, ParameterSetName = 'Credentials')]
    [Parameter(Mandatory, ParameterSetName = 'CredentialAndToken')]
    [string]$domainname
)

Import-Module "C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\Microsoft.CloudSync.PowerShell.dll" 
if ($PSCmdlet.ParameterSetName -eq 'Passwords'){
    $hybridAdminCreds = New-Object System.Management.Automation.PSCredential -ArgumentList ($hybridAdminUPN, $hybridAdminPassword) 
}
if ($PSCmdlet.ParameterSetName -ne 'CredentialAndToken'){
Connect-AADCloudSyncAzureAD -Credential $hybridAdminCreds
}
else{
    Connect-AADCloudSyncAzureAD -AccessToken $accessToken -TenantId $tenantId -UserPrincipalName $userId
}
if ($PSCmdlet.ParameterSetName -eq 'Passwords'){
    $domainAdminCreds = New-Object System.Management.Automation.PSCredential -ArgumentList ($domainAdminUPN, $domainAdminPassword) 
}
Add-AADCloudSyncGMSA -Credential $domainAdminCreds
Add-AADCloudSyncADDomain -DomainName $domainname -Credential $domainAdminCreds 

Restart-Service -Name AADConnectProvisioningAgent  
