@description('Name of the blob as it is stored in the blob container')
param filename string = 'ConfigureDC.zip'

@description('Name of the blob container')
param containerName string = 'bicep'

@description('Azure region where resources should be deployed')
param location string = resourceGroup().location

@description('Desired name of the storage account')
param storageAccountName string

param identityId string

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'

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
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: storage.name
      }
      {
        name: 'CONTENT'
        value: loadFileAsBase64('../../Blobs/ConfigureDC.zip')
      }
    ]
    scriptContent: 'echo "$CONTENT" | base64 -d > ${filename} && az storage blob upload --type block -f ${filename} -c ${containerName} -n ${filename} --auth-mode login'
  }
}
