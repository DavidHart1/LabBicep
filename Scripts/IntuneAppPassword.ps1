param (
    [string]$applicationId,
    [string]$identityId,
    [string]$vaultName
)


# Install needed modules if not already installed
if (-not (Get-Module -Name Az.Accounts -ListAvailable)) {
    Install-Module -Name Az.Accounts -Force
}
# Install needed modules if not already installed
if (-not (Get-Module -Name Microsoft.Graph.Applications -ListAvailable)) {
    Install-Module -Name Microsoft.Graph.Applications -Force
}

Import-Module Microsoft.Graph.Applications

$params = @{
	passwordCredential = @{
		displayName = "IntuneCD"
	}
}
Connect-MgGraph -Identity -ClientId $identityId
try {
    $app = Get-MgApplication -ApplicationId $applicationId
    foreach ($appPass in $app.passwordCredentials) {
        Remove-MgApplicationPassword -ApplicationId $applicationId -KeyId $appPass.KeyId
    }
}
catch {
    <#Do this if a terminating exception happens#>
}
$appPass = Add-MgApplicationPassword -ApplicationId $applicationId -BodyParameter $params

Connect-AzAccount -Identity -AccountId $identityId
Set-AzKeyVaultSecret -VaultName $vaultName -Name "IntuneCDSecret" -SecretValue (ConvertTo-SecureString -String $appPass.SecretText -AsPlainText)