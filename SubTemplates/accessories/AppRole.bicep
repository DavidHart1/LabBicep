extension microsoftGraph

param principalName string
param resourceAppId string = '00000003-0000-0000-c000-000000000000'
param appRoles array = [
  'User.Read.All'
]

resource principal 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: principalName
}

resource principalSPN 'Microsoft.Graph/servicePrincipals@v1.0' existing = {
  appId: principal.properties.clientId
}

resource resourceSpn 'Microsoft.Graph/servicePrincipals@v1.0' existing = {
  appId: resourceAppId
}

resource dcPrincipalAppRole 'Microsoft.Graph/appRoleAssignedTo@beta' = [for appRole in appRoles: {
  principalId: principalSPN.id
  resourceId: resourceSpn.id
  appRoleId: (filter(resourceSpn.appRoles, ar => ar.value == appRole)[0]).id
}]
