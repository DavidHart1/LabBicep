param principalName string
param location string

resource principal 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: principalName
  location: location
}

output principalResource string = principal.id
output principalId string = principal.properties.principalId
