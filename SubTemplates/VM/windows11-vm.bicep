param trustedSubnetId string
param publicIPId string
param virtualMachineName string
param TempUsername string
#disable-next-line secure-secrets-in-params
param TempPassword string
param virtualMachineSize string
param nsgId string
param Location string = resourceGroup().location
param domainInfo object

var trustedNicName = '${virtualMachineName}-NIC'

module trustedNic '../vnet/nic.bicep' = {
  name: trustedNicName
  params:{
    Location: Location
    nicName: trustedNicName
    subnetId: trustedSubnetId
    publicIPId: publicIPId
    enableIPForwarding: false
    nsgId: nsgId
  }
}

resource windows11 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: virtualMachineName
  location: Location
  identity: domainInfo.entraJoin ? {type: 'SystemAssigned'} : null
  properties: {
    osProfile: {
      computerName: virtualMachineName
      adminUsername: TempUsername
      adminPassword: TempPassword
    }
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
      }
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-23h2-pro'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: trustedNic.outputs.nicId
          properties:{
            primary: true
          }
        }
      ]
    }
  }
}

resource extjoindomain 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = if(domainInfo.joinAD) {
    name: 'joindomain'
    parent: windows11
    location: Location
    properties: {
      publisher: 'Microsoft.Compute'
      type: 'JsonADDomainExtension'
      typeHandlerVersion: '1.3'
      autoUpgradeMinorVersion: true
      settings: {
        name: domainInfo.dcForestName
        OUPath: domainInfo.ouPath
        user: '${domainInfo.dcForestName}\\${domainInfo.localAdminName}'
        restart: 'true'
        options: '3'
        NumberOfRetries: '4'
        RetryIntervalInMilliseconds: '30000'
      }
      protectedSettings: {
        password: domainInfo.localAdminPassword
      }
    }
  }

resource extjoinentra 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = if(domainInfo.entraJoin) {
    name: 'entrajoin'
    parent: windows11
    location: Location
    properties: {
      publisher: 'Microsoft.Azure.ActiveDirectory'
      type: 'AADLoginForWindows'
      typeHandlerVersion: '1.0'
      autoUpgradeMinorVersion: true
      settings: {
        mdmId: '000000a-0000-0000-c000-000000000000' // Intune Join
      }
    }
  }

output untrustedNicIP string = trustedNic.outputs.nicIP
