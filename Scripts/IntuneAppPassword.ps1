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
    # Only rotate the password if no valid credential exists, or if the existing
    # secret can't be verified (idempotent: skip rotation if a credential named
    # "IntuneCD" already exists and the KV secret is populated)
    $existingCred = $app.PasswordCredentials | Where-Object { $_.DisplayName -eq "IntuneCD" }

    Connect-AzAccount -Identity -AccountId $identityId
    $existingSecret = Get-AzKeyVaultSecret -VaultName $vaultName -Name "IntuneCDSecret" -ErrorAction SilentlyContinue

    if ($existingCred -and $existingSecret) {
        Write-Output "IntuneCD credential and Key Vault secret already exist, skipping password rotation."
    } else {
        Write-Output "Rotating IntuneCD app password..."
        # Remove any existing credentials
        foreach ($appPass in $app.PasswordCredentials) {
            Remove-MgApplicationPassword -ApplicationId $applicationId -KeyId $appPass.KeyId
        }
        $appPass = Add-MgApplicationPassword -ApplicationId $applicationId -BodyParameter $params
        Set-AzKeyVaultSecret -VaultName $vaultName -Name "IntuneCDSecret" -SecretValue (ConvertTo-SecureString -String $appPass.SecretText -AsPlainText)
    }
}
catch {
    Write-Output "Error managing app password: $($_.Exception.Message)"
    throw
}