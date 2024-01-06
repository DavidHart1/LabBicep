@minLength(5)
@maxLength(15)
param localAdminName string = 'HLA-Admin'

@minLength(8)
@maxLength(32)
@secure()
param localAdminPassword string

@minLength(2)
@maxLength(5)
param namePrefix string
@description('Whether or not to provision a Domain Controller')
param provisionDC bool = true
@description('Name of Az Managed Identity with User.Read.All in Entra')
param dcPrincipalName string = 'entratest'
//param dcPrincipalName string = '${namePrefix}-dcPrincipal1'
@description('Whether or not to provision LogAnalytics and Sentinel')
param provisionSentinel bool = true
//@description('Name of the Resource Group containing the virtual network')
//param vnetRGName string

//@description('Name of the Sentinel Workspace')
//param sentinelName string

var storageAccountName = toLower('${namePrefix}labsa01')
var lawName = '${namePrefix}-law01'
var dcVMName = '${namePrefix}-DC01'
// ! Change this
param dcForestName string = 'alpha.hartlabs.info' 

// Network Params
  param virtualNetworkName string = 'HLA-HubNet'
  @sys.description('Virtual Network Address Space. Only required if you want to create a new VNet.')
  param VNETAddress array = [
    '10.1.0.0/16'
  ]
  @sys.description('Untrusted-Subnet Address Space. Only required if you want to create a new VNet.')
  param UntrustedSubnetCIDR string = '10.1.0.0/24'
  @sys.description('Trusted-Subnet Address Space. Only required if you want to create a new VNet.')
  param TrustedSubnetCIDR string = '10.1.1.0/24'
  var untrustedSubnetName = 'Untrusted-Subnet'
  var trustedSubnetName = 'Trusted-Subnet'
  var windowsvmsubnetname = 'Windows-VM-Subnet'
  @sys.description('In case of deploying Windows in a New VNet this will be the Windows VM Subnet Address Space')
  param DeployWindowsSubnet string = '10.1.2.0/24'
  param GatewaySubnet string = '10.1.255.192/26'

  @sys.description('Specify Public IP SKU either Basic (lowest cost) or Standard (Required for HA LB)"')
  @allowed([
    'Basic'
    'Standard'
  ])
  param PublicIPAddressSku string = 'Standard'
  var publicIPAddressName = '${virtualMachineName}-PublicIP'
  var networkSecurityGroupName = '${virtualMachineName}-NSG'

// OPNSense VM Params
  @sys.description('OPN NVA Manchine Name')
  param virtualMachineName string = 'OPNSense'
  @sys.description('URI for Custom OPN Script and Config')
  param OpnScriptURI string = 'https://raw.githubusercontent.com/dmauser/opnazure/master/scripts/'
  @sys.description('OPN Version')
  param OpnVersion string = '23.1'
  @sys.description('Azure WALinux agent Version')
  param WALinuxVersion string = '2.9.1.1'
  @sys.description('Shell Script to be executed')
  param ShellScriptName string = 'configureopnsense.sh'
  @sys.description('OPNSense VM size, please choose a size which allow 2 NICs.')
  param virtualMachineSize string = 'Standard_B2s'
  // OPNSense Mgmt Machine Params/Vars
  var winvmroutetablename = 'winvmroutetable'
  var winvmName = 'OPNSenseAdmin'
  var winvmnetworkSecurityGroupName = '${winvmName}-NSG'
  var winvmpublicipName = '${winvmName}-PublicIP'

// Storage Account Params
  @allowed([
    'Standard_LRS'
    'Standard_GRS'
    'Standard_RAGRS'
    'Standard_ZRS'
    'Premium_LRS'
    'Premium_ZRS'
    'Standard_GZRS'
    'Standard_RAGZRS'
  ])
  param storageSKU string = 'Standard_LRS'
  param location string = 'westus3'
  param containerName string = 'bicep'

var automationName = '${namePrefix}-Auto1'
param baseTime string = utcNow('u')

// Create VNET
module vnet 'SubTemplates/vnet/vnet.bicep' = {
  name: virtualNetworkName
  params: {
    location: location
    vnetAddressSpace: VNETAddress
    vnetName: virtualNetworkName
    subnets: [
      {
        name: untrustedSubnetName
        properties: {
          addressPrefix: UntrustedSubnetCIDR
        }
      }
      {
        name: trustedSubnetName
        properties: {
          addressPrefix: TrustedSubnetCIDR
        }
      }
      {
        name: windowsvmsubnetname
        properties: {
          addressPrefix: DeployWindowsSubnet
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: GatewaySubnet
        }
      }
    ]
  }
}
// Create OPNSense Public IP
module publicip 'SubTemplates/vnet/publicip.bicep' = {
  name: publicIPAddressName
  params: {
    location: location
    publicipName: publicIPAddressName
    publicipproperties: {
      publicIPAllocationMethod: 'Static'
    }
    publicipsku: {
      name: PublicIPAddressSku
      tier: 'Regional'
    }
  }
}

// Create NSG
module nsgopnsense 'SubTemplates/vnet/nsg.bicep' = {
  name: networkSecurityGroupName
  params: {
    Location: location
    nsgName: networkSecurityGroupName
    securityRules: [
      {
        name: 'In-Any'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Out-Any'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Build reference of existing subnets
  resource untrustedSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
    name: '${virtualNetworkName}/${untrustedSubnetName}'
  }

  resource trustedSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
    name: '${virtualNetworkName}/${trustedSubnetName}'
  }

  resource windowsvmsubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing =  {
    name: '${virtualNetworkName}/${windowsvmsubnetname}'
  }

var _artifactsLocationSasToken = labSA.listServiceSas('2021-09-01', {
  canonicalizedResource: '/blob/${labSA.name}/bicep'
  signedResource: 'c'
  signedProtocol: 'https'
  signedPermission: 'r'
  signedExpiry: dateTimeAdd(baseTime, 'PT1H')
}).serviceSasToken

var _appsSasToken = labSA.listServiceSas('2021-09-01', {
  canonicalizedResource: '/blob/${labSA.name}/bicep'
  signedResource: 'c'
  signedProtocol: 'https'
  signedPermission: 'r'
  signedExpiry: dateTimeAdd(baseTime, 'P1Y')
}).serviceSasToken

// Create Automation Account
  module automator 'SubTemplates/accessories/AzAuto.bicep' = {
    name: '${automationName}-Deployment'
    params: {
      accountName: automationName
      location: location
    }
  }

// Create OPNsense TwoNics
  module opnSenseTwoNics 'SubTemplates/VM/opnsense.bicep' = {
    name: '${virtualMachineName}-TwoNics'
    params: {
      Location: location
      //ShellScriptParameters: '${OpnScriptURI} TwoNics ${trustedSubnet.properties.addressPrefix} ${DeployWindows ? windowsvmsubnet.properties.addressPrefix: '1.1.1.1/32'}'
      ShellScriptObj: {
        OpnScriptURI: OpnScriptURI
        OpnVersion: OpnVersion
        WALinuxVersion: WALinuxVersion
        OpnType: 'TwoNics'
        TrustedSubnetName: '${virtualNetworkName}/${trustedSubnetName}'
        WindowsSubnetName:  '${virtualNetworkName}/${windowsvmsubnetname}'
        publicIPAddress: ''
        opnSenseSecondarytrustedNicIP: ''
      }
      OPNScriptURI: OpnScriptURI
      ShellScriptName: ShellScriptName
      TempPassword: localAdminPassword
      TempUsername: localAdminName
      multiNicSupport: true
      trustedSubnetId: trustedSubnet.id
      untrustedSubnetId: untrustedSubnet.id
      virtualMachineName: virtualMachineName
      virtualMachineSize: virtualMachineSize
      publicIPId: publicip.outputs.publicipId
      nsgId: nsgopnsense.outputs.nsgID
    }
    dependsOn: [
      vnet
      nsgopnsense
      trustedSubnet
    ]
  }

// Windows11 Client Resources
  module nsgwinvm 'SubTemplates/vnet/nsg.bicep' = {
    name: winvmnetworkSecurityGroupName
    params: {
      Location: location
      nsgName: winvmnetworkSecurityGroupName
      securityRules: [
        {
          // TODO: Fix IP Address
          name: 'RDP'
          properties: {
            priority: 4096
            sourceAddressPrefix: '*'
            protocol: 'Tcp'
            destinationPortRange: '3389'
            access: 'Allow'
            direction: 'Inbound'
            sourcePortRange: '*'
            destinationAddressPrefix: '*'
          }
        }
        {
          name: 'Out-Any'
          properties: {
            priority: 4096
            sourceAddressPrefix: '*'
            protocol: '*'
            destinationPortRange: '*'
            access: 'Allow'
            direction: 'Outbound'
            sourcePortRange: '*'
            destinationAddressPrefix: '*'
          }
        }
      ]
    }
    dependsOn: [
      opnSenseTwoNics
    ]
  }

  module winvmpublicip 'SubTemplates/vnet/publicip.bicep' = {
    name: winvmpublicipName
    params: {
      location: location
      publicipName: winvmpublicipName
      publicipproperties: {
        publicIPAllocationMethod: 'Static'
      }
      publicipsku: {
        name: PublicIPAddressSku
        tier: 'Regional'
      }
    }
    dependsOn: [
      opnSenseTwoNics
    ]
  }

  module winvmroutetable 'SubTemplates/vnet/routetable.bicep' = {
    name: winvmroutetablename
    params: {
      location: location
      rtName: winvmroutetablename
    }
    dependsOn: [
      opnSenseTwoNics
    ]
  }

  module winvmroutetableroutes 'SubTemplates/vnet/routetableroutes.bicep' = {
    name: '${winvmroutetablename}-default'
    params: {
      routetableName: winvmroutetablename
      routeName: 'default'
      properties: {
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress:  opnSenseTwoNics.outputs.trustedNicIP
        addressPrefix: '0.0.0.0/0'
      }
    }
    dependsOn: [
      winvmroutetable
    ]
  }

  module winvm 'SubTemplates/VM/windows11-vm.bicep' = {
    name: winvmName
    params: {
      Location: location
      nsgId: nsgwinvm.outputs.nsgID
      publicIPId: winvmpublicip.outputs.publicipId
      TempUsername: localAdminName
      TempPassword: localAdminPassword
      trustedSubnetId: windowsvmsubnet.id
      virtualMachineName: winvmName
      virtualMachineSize: 'Standard_B2as_v2'
    }
    dependsOn: [
      nsgwinvm
      winvmpublicip
      opnSenseTwoNics
    ]
  }

// Create Storage Account
  resource labSA 'Microsoft.Storage/storageAccounts@2021-09-01' = {
    name: storageAccountName
    location: location
    sku: {
      name: storageSKU
    }
    kind: 'StorageV2'
    properties: {
      supportsHttpsTrafficOnly: true
    }
  }
  var saPrincipalName = '${namePrefix}-saPrincipal1'
  module saPrincipal 'SubTemplates/accessories/AzPrincipal.bicep' = {
    name: 'storageIdentity'
    params: {
      principalName: saPrincipalName
      location: location
    }
  }
  resource storageContribRoleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
    scope: subscription()
    name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  }
  resource saPrincipalBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    name: guid(resourceGroup().id, saPrincipal.name, storageContribRoleDef.id)
    scope: labSA
    properties: {
      principalId: saPrincipal.outputs.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: storageContribRoleDef.id
    }
    dependsOn: [
      saPrincipal
    ]
  }
// Upload Blobs
  module dcBlob 'SubTemplates/accessories/CopyFile.bicep' = if(provisionDC) {
    name: 'DCConfigBlob'
    scope: resourceGroup()
    params: {
      filename: 'ConfigureDC.zip'
      identityId: saPrincipal.outputs.principalResource
      location: location
      storageAccountName: labSA.name
      sourceFileUri: 'https://github.com/HartD92/LabBicepArtifacts/raw/main/Blobs/ConfigureDC.zip'
    }
    dependsOn: [
      saPrincipalBlobContributor
    ]
  }
  module AADCAgentBlob 'SubTemplates/accessories/CopyFile.bicep' = if(provisionDC) {
    name: 'AADCAgentBlob'
    scope: resourceGroup()
    params: {
      filename: 'AADConnectProvisioningAgentSetup.exe'
      identityId: saPrincipal.outputs.principalResource
      location: location
      storageAccountName: labSA.name
      sourceFileUri: 'https://github.com/HartD92/LabBicepArtifacts/raw/main/Blobs/AADConnectProvisioningAgentSetup.exe'
    }
    dependsOn: [
      saPrincipalBlobContributor
    ]
  }
// Pull Existing Managed Identity for DC to Access Entra
  resource dcPrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = if (provisionDC) {
    name: dcPrincipalName
  }

// Create VM for ADDS Domain Controller
// TODO: Once app gallery is done, configure to deploy Cloud Sync
  module CreateDCVM 'SubTemplates/WindowsVM.bicep'  = if (provisionDC) {
    name: 'CreateDCVM'
    params: {
      location: location
      networkInterfaceName: '${dcVMName}-nic1'
      subnetRef: trustedSubnet.id
      virtualMachineName: dcVMName
      virtualMachineComputerName: dcVMName
      adminUsername: localAdminName
      adminPassword: localAdminPassword
      identityId: dcPrincipal.id
      CloudSyncAppId: cloudSyncApp.outputs.appReference
      forestName: dcForestName
      dscConfigScriptName: 'ConfigureDC.ps1'
      dscConfigScriptSASToken: _artifactsLocationSasToken
      dscConfigScriptURI: '${labSA.properties.primaryEndpoints.blob}${containerName}/ConfigureDC.zip'
    }
    dependsOn: [
      vnet
      dcBlob
    ]
  }

// TODO: Figure out how to update DNS for VNet after DC is deployed.
// TODO: Maybe just have to do it on NICs for future VMS?

// Deploy Log Analytics and Sentinel
  resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = if (provisionSentinel) {
    name: lawName
    location: location
    properties: {
      sku: {
        name: 'PerGB2018'
      }
      retentionInDays: 30
      features:{
        immediatePurgeDataOn30Days:true
      }
    }
  }
  var solutionName = 'SecurityInsights(${logAnalyticsWorkspace.name})'
  resource sentinel 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = if (provisionSentinel){
    name: solutionName
    location: location
    properties: {
      workspaceResourceId: logAnalyticsWorkspace.id
    }
    plan: {
      name: solutionName
      product: 'OMSGallery/SecurityInsights'
      publisher: 'Microsoft'
      promotionCode: ''
    }
  }

// Deploy App Gallery
var appGalleryname = '${namePrefix}_AppGallery1'
module appGallery 'SubTemplates/vmapps/gallery.bicep' = {
  name: appGalleryname
  params: {
    location: location
    galleryName: appGalleryname
  }
}
// TODO: Deploy Cloud Sync in App Gallery
var sas_url = '${labSA.properties.primaryEndpoints.blob}${containerName}/AADConnectProvisioningAgentSetup.exe?${_appsSasToken}'
module cloudSyncApp 'SubTemplates/vmapps/application.bicep' = if (provisionDC) {
  name: 'CloudSync'
  params: {
    location: location
    galleryName: appGalleryname
    appName: 'CloudSync'
    fileURI: sas_url
    installCommand: '.\\AADConnectProvisioningAgentSetup.exe /quiet /norestart'
    uninstallCommand: 'uninstall.exe'
  }
  dependsOn: [
    appGallery
    AADCAgentBlob
  ]
}

output workspaceId string = logAnalyticsWorkspace.id
output workspaceName string = logAnalyticsWorkspace.name
output solutionId string = sentinel.id
output solutionName string = sentinel.name
