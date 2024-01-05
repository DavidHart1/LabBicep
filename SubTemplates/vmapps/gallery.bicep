param galleryName string
param location string

resource gallery 'Microsoft.Compute/galleries@2022-03-03' = {
  name: galleryName
  location: location
  properties: {
    description: 'Lab Compute Gallery'
  }
}

output galleryId string = gallery.id
