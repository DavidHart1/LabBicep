@description('Name of the blob as it is stored in the blob container')
param filename string

@description('Name of the blob container')
param containerName string = 'bicep'

@description('Azure region where resources should be deployed')
param location string = resourceGroup().location

@description('Desired name of the storage account')
param storageAccountName string

param identityId string
param sourceFileUri string

// TODO: Migrate to managed identity for storage access instead of key-based auth
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: {
    SecurityControl: 'Ignore'
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: true
  }

  resource blobService 'blobServices' = {
    name: 'default'

    resource container 'containers' = {
      name: containerName
    }
  }
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'deployscript-upload-blob-${filename}'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    azCliVersion: '2.52.0'
    retentionInterval: 'PT1H'
    storageAccountSettings: {
      storageAccountName: storage.name
      storageAccountKey: storage.listKeys().keys[0].value
    }
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: storage.name
      }
    ]
    scriptContent: 'wget ${sourceFileUri} && az storage blob upload --type block --content-encoding base64 --overwrite -f ${filename} -c ${containerName} -n ${filename} --auth-mode login'
  }
}
