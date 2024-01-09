param location string
param networkInterfaceName string
//param subnetName string
//param virtualNetworkId string
param subnetRef string
param virtualMachineName string
param virtualMachineComputerName string
param osDiskType string = 'StandardSSD_LRS'
param osDiskDeleteOption string = 'Delete'
param virtualMachineSize string = 'Standard_B2s'
param nicDeleteOption string = 'Delete'
param adminUsername string
param dscConfigScriptURI string
param dscConfigScriptName string
param dscConfigScriptSASToken string
param aadSetupScriptName string
param aadSetupScriptURI string
@secure()
param userPassword string
param forestName string
@secure()
param adminPassword string
param identityName string
param CloudSyncAppId string
param patchMode string = 'AutomaticByOS'
param enableHotpatching bool = false
param securityType string = 'TrustedLaunch'
param secureBoot bool = true
param vTPM bool = true

// Pull Existing Managed Identity for DC to Access Entra
  resource dcPrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
    name: identityName
  }


resource networkInterface 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
  dependsOn: []
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: virtualMachineName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${dcPrincipal.id}' : {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'fromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        deleteOption: osDiskDeleteOption
      }
      dataDisks: [
        {
          createOption: 'empty'
          lun: 0
          diskSizeGB: 64
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
      ]
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: nicDeleteOption
          }
        }
      ]
    }
    additionalCapabilities: {
      hibernationEnabled: false
    }
    osProfile: {
      computerName: virtualMachineComputerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          enableHotpatching: enableHotpatching
          patchMode: patchMode
        }
      }
    }
    applicationProfile: {
      galleryApplications: [
        {
          order: 1
          packageReferenceId: CloudSyncAppId
          treatFailureAsDeploymentFailure: true
        }
      ]
    }
    licenseType: 'Windows_Server'
    securityProfile: {
      securityType: securityType
      uefiSettings: {
        secureBootEnabled: secureBoot
        vTpmEnabled: vTPM
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource dscExtension 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: virtualMachine
  name: 'DSC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.80'
    autoUpgradeMinorVersion: true
    settings: {
      configuration: {
        url: dscConfigScriptURI
        script: dscConfigScriptName
        function: 'ConfigureDC'
      }
      configurationArguments: {
        domainName: forestName
      }
      privacy: {
        dataCollection: 'Disable'
      }
    }
    protectedSettings: {
      configurationUrlSasToken: '?${dscConfigScriptSASToken}'
      configurationArguments: {
        adminCreds: {
          userName: adminUsername
          password: adminPassword
        }
      }
    }
  }
}
var clientId = dcPrincipal.properties.clientId
// TODO: Figure out a way to use securestrings...
resource vmext 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'AADSetup'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.5'
    autoUpgradeMinorVersion: true
    settings:{
    }
    protectedSettings: {
      fileUris: [
        '${aadSetupScriptURI}'
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File .\\${aadSetupScriptName} -adminUsername ${adminUsername} -adminPassword ${adminPassword} -NewUserPassword ${userPassword} -domainName ${forestName} -ManagedIdentityClientId ${clientId}'
    }
  }
  dependsOn: [
    dscExtension
  ]
}

output adminUsername string = adminUsername
output dcIP string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress
