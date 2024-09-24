extension microsoftGraph

@minLength(5)
@maxLength(15)
param localAdminName string

@minLength(8)
@maxLength(32)
@secure()
param localAdminPassword string

@minLength(5)
@maxLength(40)
param AzAdminName string

@minLength(8)
@maxLength(32)
@secure()
param AzAdminPassword string

@minLength(8)
@maxLength(32)
@secure()
param adUserPassword string

@minLength(2)
@maxLength(5)
param namePrefix string
@description('Whether or not to provision a Domain Controller')
param provisionDC bool = true
// Right Now this only skips the actual provisioning. It doesn't properly adjust the route table, NSG, etc.
@description('Whether or not to provision OPNSense')
param provisionOPNSense bool = true
@description('Name of Az Managed Identity with User.Read.All in Entra')
param dcPrincipalName string
//param dcPrincipalName string = '${namePrefix}-dcPrincipal1'
@description('Whether or not to provision LogAnalytics and Sentinel')
param provisionSentinel bool = false
@description('Whether or not to provision an AD-Joined Windows 11 VM')
param provisionWindowsVM {
  provision: bool
  nameSuffix: string
  ouPath: string
}
@description('Whether or not to provision an Entra-Joined Windows 11 VM')
param provisionEntraWindowsVM {
  provision: bool
  nameSuffix: string
} = {nameSuffix: 'entra', provision: true}
@description('Whether or not to provision an AzSQL VM, and what to suffix it. Will be namePrefix-nameSuffix')
param azSQL {
  provision: bool
  nameSuffix: string
  adminGroupName: string
  groupExisting: bool
} = {nameSuffix: 'azsql1', provision: true, adminGroupName: 'sg-IT', groupExisting: false}
@description('Whether or not to provision Intune')
param intune {
  provision: bool
  nameSuffix: string
} = {provision: true, nameSuffix: 'intunecd'}
//@description('Name of the Resource Group containing the virtual network')
//param vnetRGName string

//@description('Name of the Sentinel Workspace')
//param sentinelName string

var storageAccountName = toLower('${namePrefix}labsa01')
var lawName = '${namePrefix}-law01'
var dcVMName = '${namePrefix}-DC01'
// ! Change this
param dcForestName string

// Network Params
  param virtualNetwork {
    provisionNew: bool
    containerSubnet: {
      name: string
      addressPrefix: string
    }
  }
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
  param OpnVersion string = '24.7'
  @sys.description('Azure WALinux agent Version')
  param WALinuxVersion string = '2.11.1.4'
  @sys.description('Shell Script to be executed')
  param ShellScriptName string = 'configureopnsense.sh'
  @sys.description('OPNSense VM size, please choose a size which allow 2 NICs.')
  param virtualMachineSize string = 'Standard_B2s'
  // OPNSense Mgmt Machine Params/Vars
  // TODO: Change this to another object param like provision EntraWindowsVM
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
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
              locations: [
                '${location}'
              ]
            }
          ]
        }
      }
      {
        name: windowsvmsubnetname
        properties: {
          addressPrefix: DeployWindowsSubnet
        }
      }
      {
        name: virtualNetwork.containerSubnet.name
        properties: {
          addressPrefix: virtualNetwork.containerSubnet.addressPrefix
          delegations: [
            {
              name: 'Microsoft.ContainerInstance/containerGroups'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
              locations: [
                '${location}'
              ]
            }
          ]
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
module publicip 'SubTemplates/vnet/publicip.bicep' = if (provisionOPNSense) {
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
  resource untrustedSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = if(!virtualNetwork.provisionNew) {
    name: '${virtualNetworkName}/${untrustedSubnetName}'
  }

  resource trustedSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = if(!virtualNetwork.provisionNew) {
    name: '${virtualNetworkName}/${trustedSubnetName}'
  }

  resource windowsvmsubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = if(!virtualNetwork.provisionNew) {
    name: '${virtualNetworkName}/${windowsvmsubnetname}'
  }
  resource containerSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = if(!virtualNetwork.provisionNew) {
    name: '${virtualNetworkName}/${virtualNetwork.containerSubnet.name}'
  }

// Pull Existing Managed Identity for DC to Access Entra

  resource dcPrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
    name: dcPrincipalName
    location: location
  }

  module dcPrincipalAppRole 'SubTemplates/accessories/AppRole.bicep' = {
    name: '${dcPrincipalName}-AppRoles'
    params: {
      principalName: dcPrincipalName
      //resourceAppId: '00000003-0000-0000-c000-000000000000'
      appRoles: [
        'User.Read.All'
        'Application.ReadWrite.All'
        'AuditLog.Read.All'
        'AuditLogsQuery.Read.All'
        'AuthenticationContext.ReadWrite.All'
        'Directory.ReadWrite.All'
        'Domain.ReadWrite.All'
        'OnPremisesPublishingProfiles.ReadWrite.All'
        'OnPremDirectorySynchronization.ReadWrite.All'
        'ServicePrincipalEndpoint.ReadWrite.All'
      ]
    }
    dependsOn: [
      dcPrincipal
    ]
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
  module opnSenseTwoNics 'SubTemplates/VM/opnsense.bicep' = if (provisionOPNSense){
    name: '${virtualMachineName}-TwoNics'
    params: {
      Location: location
      //ShellScriptParameters: '${OpnScriptURI} TwoNics ${trustedSubnet.properties.addressPrefix} ${DeployWindows ? windowsvmsubnet.properties.addressPrefix: '1.1.1.1/32'}'
      ShellScriptObj: {
        OpnScriptURI: OpnScriptURI
        OpnVersion: OpnVersion
        WALinuxVersion: WALinuxVersion
        OpnType: 'TwoNics'
        TrustedSubnetName: '${vnet.outputs.vnetName}/${trustedSubnetName}'
        WindowsSubnetName:  '${vnet.outputs.vnetName}/${windowsvmsubnetname}'
        publicIPAddress: ''
        opnSenseSecondarytrustedNicIP: ''
      }
      OPNScriptURI: OpnScriptURI
      ShellScriptName: ShellScriptName
      TempPassword: localAdminPassword
      TempUsername: localAdminName
      multiNicSupport: true
      trustedSubnetId: (!virtualNetwork.provisionNew) ? vnet.outputs.vnetSubnets[1].id : trustedSubnet.id
      untrustedSubnetId: (!virtualNetwork.provisionNew) ? vnet.outputs.vnetSubnets[0].id : untrustedSubnet.id
      virtualMachineName: virtualMachineName
      virtualMachineSize: virtualMachineSize
      publicIPId: publicip.outputs.publicipId
      nsgId: nsgopnsense.outputs.nsgID
    }
    dependsOn: [
      vnet
      nsgopnsense
    ]
  }

  // OPNSense Admin Resources
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
  }

  module winvmpublicip 'SubTemplates/vnet/publicip.bicep' = {
    name: '${deployment().name}-${winvmpublicipName}'
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
      vnet
    ]
  }

  resource opnSenseTrustedNic 'Microsoft.Network/networkInterfaces@2023-05-01' existing = if (!provisionOPNSense) {
    name: '${virtualMachineName}-Trusted-NIC'
  }
  // resource opnSenseUntrustedNic 'Microsoft.Network/networkInterfaces@2023-05-01' existing = if (!provisionOPNSense) {
  //   name: '${virtualMachineName}-Untrusted-NIC'
  // }

  module winvmroutetable 'SubTemplates/vnet/routetable.bicep' = {
    name: '${deployment().name}-${winvmroutetablename}'
    params: {
      location: location
      rtName: winvmroutetablename
    }
    dependsOn: [
      vnet
    ]
  }

  module winvmroutetableroutes 'SubTemplates/vnet/routetableroutes.bicep' = {
    name: '${winvmroutetablename}-default'
    params: {
      routetableName: winvmroutetablename
      routeName: 'default'
      properties: {
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress:  (provisionOPNSense) ? opnSenseTwoNics.outputs.trustedNicIP : opnSenseTrustedNic.properties.ipConfigurations[0].properties.privateIPAddress
        addressPrefix: '0.0.0.0/0'
      }
    }
    dependsOn: [
      winvmroutetable
    ]
  }

  module winvm 'SubTemplates/VM/windows11-vm.bicep' = {
    name: '${deployment().name}-${winvmName}'
    params: {
      Location: location
      nsgId: nsgwinvm.outputs.nsgID
      publicIPId: winvmpublicip.outputs.publicipId
      TempUsername: localAdminName
      TempPassword: localAdminPassword
      trustedSubnetId: (!virtualNetwork.provisionNew) ? vnet.outputs.vnetSubnets[2].id : windowsvmsubnet.id
      virtualMachineName: winvmName
      virtualMachineSize: virtualMachineSize
      domainInfo: {
        joinAD: false
      }
    }
    dependsOn: [
      nsgwinvm
      winvmpublicip
    ]
  }

  // Windows11 AD Joined Client Resources
  // TODO: We need to provision this AFTER the DC is fully deployed
  // TODO: We need to update the DNS settings on the VNet to point to the DC. Azure may give us issues iwth this.
  // TODO: Need to write a powershell script to join the domain and reboot. Can we use creds in KV?
  module nsgwinvm1 'SubTemplates/vnet/nsg.bicep' = if(provisionWindowsVM.provision) {
    name: '${namePrefix}-${provisionWindowsVM.nameSuffix}-nsg'
    params: {
      Location: location
      nsgName: '${namePrefix}-${provisionWindowsVM.nameSuffix}-nsg'
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
  }

  module winvmpublicip1 'SubTemplates/vnet/publicip.bicep' = if(provisionWindowsVM.provision) {
    name: '${deployment().name}-${namePrefix}-${provisionWindowsVM.nameSuffix}-pip'
    params: {
      location: location
      publicipName: '${namePrefix}-${provisionWindowsVM.nameSuffix}-pip'
      publicipproperties: {
        publicIPAllocationMethod: 'Static'
      }
      publicipsku: {
        name: PublicIPAddressSku
        tier: 'Regional'
      }
    }
    dependsOn: [
      vnet
    ]
  }
  resource vnetDnsUpdateScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = if (provisionDC) {
    name: 'vnetDnsUpdateScript'
    location: location
    kind: 'AzurePowerShell'
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${vnetPrincipal.id}': {}
      }
    }
    properties: {
      retentionInterval: 'PT1H'
      arguments: ' -resourceGroupName ${resourceGroup().name} -vnetName ${virtualNetworkName} -identityId ${vnetPrincipal.properties.clientId} -dcVMName ${dcVMName}'
      azPowerShellVersion: '9.7'
      scriptContent: loadTextContent('./Scripts/SetVnetDNS.ps1')
    }
    dependsOn: [
      vnetPrincipalContributor
      vnetPrincipalVMContributor
      CreateDCVM
    ]
  }

  module winvm1 'SubTemplates/VM/windows11-vm.bicep' = if(provisionWindowsVM.provision) {
    name: '${deployment().name}-${namePrefix}-${provisionWindowsVM.nameSuffix}'
    params: {
      Location: location
      nsgId: nsgwinvm1.outputs.nsgID
      publicIPId: winvmpublicip1.outputs.publicipId
      TempUsername: localAdminName
      TempPassword: localAdminPassword
      trustedSubnetId: (!virtualNetwork.provisionNew) ? vnet.outputs.vnetSubnets[2].id : windowsvmsubnet.id
      virtualMachineName: '${namePrefix}-${provisionWindowsVM.nameSuffix}'
      virtualMachineSize: virtualMachineSize
      domainInfo: {
        domainName: dcForestName
        ouPath: provisionWindowsVM.ouPath
        joinAD: true
        localAdminName: localAdminName
        localAdminPassword: localAdminPassword
      }
    }
    dependsOn: [
      nsgwinvm1
      winvmpublicip1
      vnetDnsUpdateScript
    ]
  }

  // Windows11 AAD Joined Client Resources

  module nsgwinvm2 'SubTemplates/vnet/nsg.bicep' = if(provisionEntraWindowsVM.provision) {
    name: '${namePrefix}-${provisionEntraWindowsVM.nameSuffix}-nsg'
    params: {
      Location: location
      nsgName: '${namePrefix}-${provisionEntraWindowsVM.nameSuffix}-nsg'
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
  }

  module winvmpublicip2 'SubTemplates/vnet/publicip.bicep' = if(provisionEntraWindowsVM.provision) {
    name: '${deployment().name}-${namePrefix}-${provisionEntraWindowsVM.nameSuffix}-pip'
    params: {
      location: location
      publicipName: '${namePrefix}-${provisionEntraWindowsVM.nameSuffix}-pip'
      publicipproperties: {
        publicIPAllocationMethod: 'Static'
      }
      publicipsku: {
        name: PublicIPAddressSku
        tier: 'Regional'
      }
    }
    dependsOn: [
      vnet
    ]
  }

  module winvm2 'SubTemplates/VM/windows11-vm.bicep' = if(provisionEntraWindowsVM.provision) {
    name: '${deployment().name}-${namePrefix}-${provisionEntraWindowsVM.nameSuffix}'
    params: {
      Location: location
      nsgId: nsgwinvm2.outputs.nsgID
      publicIPId: winvmpublicip2.outputs.publicipId
      TempUsername: localAdminName
      TempPassword: localAdminPassword
      trustedSubnetId: (!virtualNetwork.provisionNew) ? vnet.outputs.vnetSubnets[2].id : windowsvmsubnet.id
      virtualMachineName: '${namePrefix}-${provisionEntraWindowsVM.nameSuffix}'
      virtualMachineSize: virtualMachineSize
      domainInfo: {
        joinAD: false
        entraJoin: true
      }
    }
    dependsOn: [
      nsgwinvm2
      winvmpublicip2
    ]
  }
  // TODO: add an rbac assignment for entra vm sign in.

// Get SQL Group
  //resource sqlAdminGroup 'Microsoft.Graph/groups@v1.0' existing = if(azSQL.groupExisting) {
  //  uniqueName: azSQL.adminGroupName
  //}
  module sqlAdminGroup 'SubTemplates/accessories/EntraGroup.bicep' = {
    name: '${deployment().name}-${azSQL.adminGroupName}'
    params: {
      groupName: azSQL.adminGroupName
    }
  }

// Create Azure SQL Server
  resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
    name: '${namePrefix}-sql01'
    location: location
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      administratorLogin: localAdminName
      administratorLoginPassword: localAdminPassword
      administrators:{
        administratorType: 'ActiveDirectory'
        azureADOnlyAuthentication: false
        login: AzAdminName
        principalType: 'Group'
        tenantId: subscription().tenantId
        sid: sqlAdminGroup.outputs.groupSid
      }
      version: '12.0'
    }
  }
  
  resource sqlDB 'Microsoft.Sql/servers/databases@2023-08-01-preview' = if(azSQL.provision) {
    parent: sqlServer
    name: '${namePrefix}-sqldb01'
    location: location
    sku: {
      name: 'S0'
      tier: 'Standard'
    }
  }
  // Create Intune DB
  resource intuneCDDB 'Microsoft.Sql/servers/databases@2023-08-01-preview' = if(intune.provision) {
    parent: sqlServer
    name: '${namePrefix}-IntuneCDDB'
    location: location
    sku: {
      name: 'S0'
      tier: 'Standard'
    }
    properties: {
      collation: 'SQL_Latin1_General_CP1_CI_AS'
    }
  }
  // TODO: Create Intune CD Webapp
  resource kvAdminPrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
    name: '${namePrefix}-kvPrincipal1'
    location: location
  }
  resource scriptKVRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    name: guid(kv.id, '${namePrefix}-kvadmin', kvAdminRoleDef.id)
    scope: kv
    properties: {
      principalId: kvAdminPrincipal.properties.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: kvAdminRoleDef.id
    }
    dependsOn: [
      keyVault
    ]
  }
  resource storageDataPrivRoleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
    scope: subscription()
    name: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
  }
  resource scriptSAContribRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    name: guid(labSA.id, kvAdminPrincipal.name, storageDataPrivRoleDef.id)
    scope: labSA
    properties: {
      principalId: kvAdminPrincipal.properties.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: storageDataPrivRoleDef.id
    }
  }
  module scriptAppRWRole './SubTemplates/accessories/AppRole.bicep' = {
    name: '${deployment().name}-scriptAppRWRole'
    params: {
      principalName: kvAdminPrincipal.name
      appRoles: [
        'Application.ReadWrite.All'
      ]
    }
  }
  resource intuneAppPassScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
    name: 'DeploymentScript-CreateIntuneAppPassword'
    location: location
    kind: 'AzurePowerShell'
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${kvAdminPrincipal.id}': {}
      }
    }
    properties: {
      retentionInterval: 'PT1H'
      arguments: ' -applicationId ${intuneEntraApp.outputs.appObjectId} -identityId ${kvAdminPrincipal.properties.clientId} -vaultName ${keyVault.outputs.keyVaultName}'
      azPowerShellVersion: '12.1'
      scriptContent: loadTextContent('./Scripts/IntuneAppPassword.ps1')
      storageAccountSettings: {
        storageAccountName: labSA.name
      }
      containerSettings: {
        subnetIds: [
          {
            id: (!virtualNetwork.provisionNew) ? vnet.outputs.vnetSubnets[3].id : containerSubnet.id
          }
        ]
      }
    }
    dependsOn: [
      keyVault
      intuneEntraApp
      scriptAppRWRole
    ]
  }
  module intuneEntraApp 'SubTemplates/intune/IntuneCD.bicep' = {
    name: '${deployment().name}-${namePrefix}-IntuneCDEntraApp'
    params: {
      namePrefix: namePrefix
    }
    dependsOn: [
    ]
  }

  resource kvAdminRoleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
    scope: subscription()
    name: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  }

  resource intuneKVRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    name: guid(kv.id, '${namePrefix}-IntuneCD', kvAdminRoleDef.id)
    scope: kv
    properties: {
      principalId: intuneEntraApp.outputs.spId
      principalType: 'ServicePrincipal'
      roleDefinitionId: kvAdminRoleDef.id
    }
    dependsOn: [
      keyVault
      intuneEntraApp
    ]
  }

  resource intuneCDWebServer 'Microsoft.Web/serverfarms@2023-12-01' = {
    name: '${namePrefix}-IntuneCDFarm'
    location: location
    kind: 'app,linux'
    properties: {
      reserved: true
      targetWorkerSizeId: 0
      targetWorkerCount: 1
    }
    sku: {
      name: 'B1'
    }
  }
  module intuneWebApp 'SubTemplates/intune/IntuneWebApp.bicep' = {
    name: '${deployment().name}-${namePrefix}-IntuneCDWebApp'
    params: {
      dbadmin: localAdminName
      dbadminpass: localAdminPassword
      dbname: intuneCDDB.name
      farmId: intuneCDWebServer.id
      keyvault: keyVault.outputs.keyVaultObject
      location: location
      name: '${namePrefix}-IntuneCD'
      tz: 'America/Denver'
      url: 'https://${namePrefix}-IntuneCD.azurewebsites.net'
      webappClientId: intuneEntraApp.outputs.appId
      webappClientSecret: kv.getSecret('IntuneCDSecret')
    }
    dependsOn: [
      keyVault
      intuneEntraApp
      intuneAppPassScript
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
  module EntraNetworkBlob 'SubTemplates/accessories/CopyFile.bicep' = if(provisionDC) {
    name: 'EntraPNCBlob'
    scope: resourceGroup()
    params: {
      filename: 'MicrosoftEntraPrivateNetworkConnectorInstaller.exe'
      identityId: saPrincipal.outputs.principalResource
      location: location
      storageAccountName: labSA.name
      sourceFileUri: 'https://github.com/HartD92/LabBicepArtifacts/raw/main/Blobs/MicrosoftEntraPrivateNetworkConnectorInstaller.exe'
    }
    dependsOn: [
      saPrincipalBlobContributor
    ]
  }
  module AADSetupBlob 'SubTemplates/accessories/CopyFile.bicep' = if(provisionDC) {
    name: 'AADSetupBlob'
    scope: resourceGroup()
    params: {
      filename: 'AADSetup.ps1'
      identityId: saPrincipal.outputs.principalResource
      location: location
      storageAccountName: labSA.name
      sourceFileUri: 'https://github.com/HartD92/LabBicepArtifacts/raw/main/Blobs/AADSetup.ps1'
    }
    dependsOn: [
      saPrincipalBlobContributor
    ]
  }
  module ConfigCSBlob 'SubTemplates/accessories/CopyFile.bicep' = if(provisionDC) {
    name: 'ConfigCSBlob'
    scope: resourceGroup()
    params: {
      filename: 'ConfigureCloudSync.ps1'
      identityId: saPrincipal.outputs.principalResource
      location: location
      storageAccountName: labSA.name
      sourceFileUri: 'https://github.com/HartD92/LabBicepArtifacts/raw/main/Blobs/ConfigureCloudSync.ps1'
    }
    dependsOn: [
      saPrincipalBlobContributor
    ]
  }
  module DCSOrchBlob 'SubTemplates/accessories/CopyFile.bicep' = if(provisionDC) {
    name: 'DCSOrchBlob'
    scope: resourceGroup()
    params: {
      filename: 'DCSetupOrchestrator.ps1'
      identityId: saPrincipal.outputs.principalResource
      location: location
      storageAccountName: labSA.name
      sourceFileUri: 'https://github.com/HartD92/LabBicepArtifacts/raw/main/Blobs/DCSetupOrchestrator.ps1'
    }
    dependsOn: [
      saPrincipalBlobContributor
    ]
  }

// Create VM for ADDS Domain Controller
// TODO: Once app gallery is done, configure to deploy Cloud Sync
  module CreateDCVM 'SubTemplates/WindowsVM.bicep'  = if (provisionDC) {
    name: 'CreateDCVM'
    params: {
      location: location
      networkInterfaceName: '${dcVMName}-nic1'
      subnetRef: (!virtualNetwork.provisionNew) ? vnet.outputs.vnetSubnets[1].id : trustedSubnet.id
      virtualMachineName: dcVMName
      virtualMachineComputerName: dcVMName
      virtualMachineSize: virtualMachineSize
      adminUsername: localAdminName
      adminPassword: localAdminPassword
      identityName: dcPrincipalName
      appIds: [
        cloudSyncApp.outputs.appReference
        EntraPNCApp.outputs.appReference
      ]
      forestName: dcForestName
      dscConfigScriptName: 'ConfigureDC.ps1'
      dscConfigScriptSASToken: _artifactsLocationSasToken
      dscConfigScriptURI: '${labSA.properties.primaryEndpoints.blob}${containerName}/ConfigureDC.zip'
      aadSetupScriptName: 'DCSetupOrchestrator.ps1'
      aadSetupScriptURIs: [
        '${labSA.properties.primaryEndpoints.blob}${containerName}/ConfigureCloudSync.ps1?${_artifactsLocationSasToken}'
        '${labSA.properties.primaryEndpoints.blob}${containerName}/AADSetup.ps1?${_artifactsLocationSasToken}'
        '${labSA.properties.primaryEndpoints.blob}${containerName}/DCSetupOrchestrator.ps1?${_artifactsLocationSasToken}'
      ]
      keyVaultParameters: {
        VaultName: '${namePrefix}-kv1'
        AzAdminSecretName:'AzAdminName'
        AzPassSecretName: 'AzAdminPassword'
        DomainAdminSecretName: 'localAdminName'
        DomainPassSecretName: 'localAdminPassword'
        DomainUserSecretName: 'adUserPassword'
      }
    }
    dependsOn: [
      vnet
      dcBlob
      AADSetupBlob
      ConfigCSBlob
      DCSOrchBlob
    ]
  }

  // Deploy vnet Contributor principal for DNS Update script
  resource vnetPrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (provisionDC) {
    name: '${namePrefix}-vnetId1'
    location: location
  }
  resource vnetContribRoleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = if (provisionDC) {
    scope: subscription()
    name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  }
  resource vmContribRoleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = if (provisionDC) {
    scope: subscription()
    name: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
  }
  resource vnetPrincipalContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (provisionDC) {
    name: guid(resourceGroup().id, vnetPrincipal.name, vnetContribRoleDef.id)
    scope: resourceGroup()
    properties: {
      principalId: vnetPrincipal.properties.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: vnetContribRoleDef.id
    }
  }
  resource vnetPrincipalVMContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (provisionDC) {
    name: guid(resourceGroup().id, vnetPrincipal.name, vmContribRoleDef.id)
    scope: resourceGroup()
    properties: {
      principalId: vnetPrincipal.properties.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: vmContribRoleDef.id
    }
  }

// Deploy Log Analytics and Sentinel
  resource sentinelPrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (provisionSentinel) {
    name: '${namePrefix}-sentinelId1'
    location: location
  }
  resource sentinelContribRoleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = if (provisionSentinel) {
    scope: subscription()
    name: 'ab8e14d6-4a74-4a29-9ba8-549422addade'
  }
  resource sentinelPrincipalContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (provisionSentinel) {
    name: guid(resourceGroup().id, sentinelPrincipal.name, sentinelContribRoleDef.id)
    scope: resourceGroup()
    properties: {
      principalId: sentinelPrincipal.properties.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: sentinelContribRoleDef.id
    }
  }
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
  resource sentinelDeploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = if (provisionSentinel) {
    name: 'SentinelDeploymentScript'
    location: location
    kind: 'AzurePowerShell'
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${sentinelPrincipal.id}': {}
      }
    }
    properties: {
      retentionInterval: 'PT1H'
      arguments: ' -resourceGroupName ${resourceGroup().name} -workspaceName ${logAnalyticsWorkspace.name} -subscriptionId ${subscription().subscriptionId} -managedidentityclientid ${sentinelPrincipal.properties.clientId}'
      azPowerShellVersion: '9.7'
      scriptContent: loadTextContent('./Scripts/SentinelSetup.ps1')
    }
    dependsOn: [
      sentinelPrincipalContributor
      sentinel
    ]
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
// Deploy Cloud Sync in App Gallery
  module cloudSyncApp 'SubTemplates/vmapps/application.bicep' = if (provisionDC) {
    name: 'CloudSync'
    params: {
      location: location
      galleryName: appGalleryname
      appName: 'CloudSync'
      fileURI: '${labSA.properties.primaryEndpoints.blob}${containerName}/AADConnectProvisioningAgentSetup.exe?${_appsSasToken}'
      installCommand: '.\\AADConnectProvisioningAgentSetup.exe /quiet /norestart'
      uninstallCommand: 'uninstall.exe'
    }
    dependsOn: [
      appGallery
      AADCAgentBlob
    ]
  }
  module EntraPNCApp 'SubTemplates/vmapps/application.bicep' = if (provisionDC) {
    name: 'EntraPNC'
    params: {
      location: location
      galleryName: appGalleryname
      appName: 'EntraPrivateNetworkConnector'
      fileURI: '${labSA.properties.primaryEndpoints.blob}${containerName}/MicrosoftEntraPrivateNetworkConnectorInstaller.exe?${_appsSasToken}'
      installCommand: '.\\MicrosoftEntraPrivateNetworkConnectorInstaller.exe REGISTERCONNECTOR="false" /q'
      uninstallCommand: 'uninstall.exe'
    }
    dependsOn: [
      appGallery
      EntraNetworkBlob
    ]
  }
// Key Vault and Secrets
  // Build kv so we can use it later
  resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
    name: '${namePrefix}-kv1'
    location: location
    properties: {sku: {family: 'A', name: 'standard'}, tenantId: tenant().tenantId, accessPolicies:[], enableSoftDelete: false}
  }
  // finish making the kv
  module keyVault 'SubTemplates/accessories/keyvault.bicep' = {
    name: '${namePrefix}-kv1'
    params: {
      location: location
      keyVaultName: '${namePrefix}-kv1'
      accessPolicies: [ {
          tenantId: subscription().tenantId
          objectId: dcPrincipal.properties.principalId
          permissions: {
            secrets: [
              'get'
              'list'
            ]
          }
        }, {
          tenantId: subscription().tenantId
          objectId: kvAdminPrincipal.properties.principalId
          permissions: {
            secrets: [
              'set'
              'list'
            ]
          }
        } ]
      networkAcls: {
        bypass: 'AzureServices'
        defaultAction: 'Deny'
        ipRules: []
        virtualNetworkRules: [
          {
            id: (!virtualNetwork.provisionNew) ? vnet.outputs.vnetSubnets[1].id : trustedSubnet.id
            ignoreMissingVnetServiceEndpoint: false
          }
          {
            id: (!virtualNetwork.provisionNew) ? vnet.outputs.vnetSubnets[3].id : containerSubnet.id
            ignoreMissingVnetServiceEndpoint: false
          }
        ]
      }
      secrets: [
        {
          name: 'adUserPassword'
          contentType: 'Password'
          value: adUserPassword
        }
        {
          name: 'localAdminPassword'
          contentType: 'Password'
          value: localAdminPassword
        }
        {
          name: 'localAdminName'
          contentType: 'Username'
          value: localAdminName
        }
        {
          name: 'AzAdminPassword'
          contentType: 'Password'
          value: AzAdminPassword
        }
        {
          name: 'AzAdminName'
          contentType: 'Username'
          value: AzAdminName
        }
        {
          name: 'entraPrincipalId'
          contentType: 'ClientId'
          value: saPrincipal.outputs.principalId
        }
      ]
    }
    dependsOn: [
      saPrincipal
    ]
  }


output workspaceId string = logAnalyticsWorkspace.id
output workspaceName string = logAnalyticsWorkspace.name
output solutionId string = sentinel.id
output solutionName string = sentinel.name
