param appName string
param location string
param description string = 'App Description'
param supportedOSType string = 'Windows'
param galleryName string
param fileURI string
param installCommand string
param uninstallCommand string

resource gallery 'Microsoft.Compute/galleries@2022-08-03' existing = {
  name: galleryName
}

resource application 'Microsoft.Compute/galleries/applications@2022-08-03' = {
  name: appName
  location: location
  parent: gallery
  properties: {
    description: description
    supportedOSType: supportedOSType
  }
}

resource appVersion 'Microsoft.Compute/galleries/applications/versions@2022-08-03' = {
  name: '1.0.0'
  location: location
  parent: application
  properties: {
    publishingProfile: {
      source: {
        mediaLink: fileURI
      }
      manageActions: {
        install: installCommand
        remove: uninstallCommand
      }
      storageAccountType: 'Standard_LRS'
    }
  }
}
