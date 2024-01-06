param vnetAddressSpace array
param vnetName string
param subnets array
param location string = resourceGroup().location
param hasDNS bool = false
param dnsServers array = []

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = if(!hasDNS) {
  name: vnetName
  location: location
  properties: {
    addressSpace:{
      addressPrefixes: vnetAddressSpace
    }
    subnets: subnets
  }
}

resource vnetdns 'Microsoft.Network/virtualNetworks@2023-05-01' = if(hasDNS) {
  name: vnetName
  location: location
  properties: {
    addressSpace:{
      addressPrefixes: vnetAddressSpace
    }
    subnets: subnets
    dhcpOptions: {
      dnsServers: dnsServers
    }
  }
}

output vnetId string = (!hasDNS) ? vnet.id:vnetdns.id
output vnetName string = (!hasDNS) ? vnet.name:vnetdns.name
output vnetSubnets array = (!hasDNS) ? vnet.properties.subnets:vnetdns.properties.subnets
output vnetDNS array = (!hasDNS) ? []:vnetdns.properties.dhcpOptions.dnsServers
