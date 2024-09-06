extension microsoftGraph

param groupName string
param groupMail bool = false
param securityGroup bool = true

resource group 'Microsoft.Graph/groups@v1.0' = {
  displayName: groupName
  mailEnabled: groupMail
  mailNickname: groupName
  securityEnabled: securityGroup
  uniqueName: groupName
}

output groupSid string = group.id
