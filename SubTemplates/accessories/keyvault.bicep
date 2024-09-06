param keyVaultName string
param location string
param networkAcls object
param accessPolicies array
param secrets array = []

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenant().tenantId
    accessPolicies: accessPolicies
    /* accessPolicies: [
      {
        applicationId: dcPrincipal.properties.principalId
        objectId: dcPrincipal.properties.clientId
        tenantId: dcPrincipal.properties.tenantId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ] */
    createMode: 'default'
    enableRbacAuthorization: false
    enabledForTemplateDeployment: true
    publicNetworkAccess: 'Enabled'
    networkAcls: networkAcls
    sku: {
      family: 'A'
      name: 'standard'
    }
  }
}

resource keyVaultSecrets 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = [for secret in secrets: {
  name: secret.name
  parent: keyVault
  properties: {
    contentType: secret.contentType
    value: secret.value
  }
}]

output keyVaultId string = keyVault.id
output keyVaultURI string = keyVault.properties.vaultUri
output keyVaultObject object = keyVault
output keyVaultName string = keyVault.name
