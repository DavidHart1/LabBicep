param accountName string
param location string

resource automator 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: accountName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    disableLocalAuth: true
    encryption: {
      keySource: 'Microsoft.Automation'
    }
    sku: {
      capacity: null
      family: null
      name: 'Basic'
    }

  }
}
