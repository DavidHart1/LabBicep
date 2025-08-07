extension graphV1
extension graphBeta

param namePrefix string
param randomString string

resource intuneEntraApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: '${namePrefix}-IntuneCD'
  signInAudience: 'AzureADMultipleOrgs'
  uniqueName: '${namePrefix}-IntuneCD'
  web: {
    redirectUris: [
      'https://${namePrefix}IntuneCD-${randomString}.azurewebsites.net/auth/signin-oidc'
      'https://${namePrefix}IntuneCD-${randomString}.azurewebsites.net/tenants'
    ]
  }
  appRoles: [
    {
      allowedMemberTypes: [
        'User'
      ]
      description: 'Administrator access to IntuneCD'
      displayName: 'Administrators'
      id: 'd1c2ade8-98f8-45fd-aa4a-6d06b947c66f'
      isEnabled: true
      value: 'intunecd_admin'
    }
  ]
  requiredResourceAccess: [
    {
      resourceAppId: '00000003-0000-0000-c000-000000000000'
      resourceAccess: [
       // DeviceManagementApps.ReadWrite.All
        {id: '78145de6-330d-4800-a6ce-494ff2d33d07', type: 'Role'}
       // DeviceManagementConfiguration.ReadWrite.All
        {id: '9241abd9-d0e6-425a-bd4f-47ba86e767a4', type: 'Role'}
       // DeviceManagementServiceConfig.ReadWrite.All
        {id: '5ac13192-7ace-4fcf-b828-1a26f28068ee', type: 'Role'}
       // DeviceManagementRBAC.ReadWrite.All
       {id: 'e330c4f0-4170-414e-a55a-2f022ec2b57b', type: 'Role'}
        // Group.ReadWrite.All
        {id: '62a82d76-70ea-41e2-9197-370581804d09', type: 'Role'}
        // Policy.Read.All
        {id: '246dd0d5-5bd0-4def-940b-0421030a5b68', type: 'Role'}
        // Policy.ReadWrite.ConditionalAccess
        {id: '01c0a623-fc9b-48e9-b794-0756f8e8f067', type: 'Role'}
        // Application
        {id: '9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30', type: 'Role'}
        // Policy.ReadWrite.AuthenticationFlows
        {id: '25f85f3c-f66c-4205-8cd5-de92dd7f0cec', type: 'Role'}
        // Policy.ReadWrite.AuthenticationMethod
        {id: '29c18626-4985-4dcd-85c0-193eef327366', type: 'Role'}
        // Policy.ReadWrite.Authorization
        {id: 'fb221be6-99f2-473f-bd32-01c6a0e9ca3b', type: 'Role'}
        // Policy.ReadWrite.ExternalIdentities
        {id: '03cc4f92-788e-4ede-b93f-199424d144a5', type: 'Role'}
        // Policy.ReadWrite.ExternalIdentities
        {id: '1c6e93a6-28e2-4cbb-9f64-1a46a821124d', type: 'Role'}
        // Policy.ReadWrite.DeviceConfiguration might also be needed, but it's Delegated only?
     ]
    }
  ]
}
resource intuneEntraSP 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: intuneEntraApp.appId
}

output appName string = intuneEntraApp.displayName
output appId string = intuneEntraApp.appId
output appObjectId string = intuneEntraApp.id
output spId string = intuneEntraSP.appId
