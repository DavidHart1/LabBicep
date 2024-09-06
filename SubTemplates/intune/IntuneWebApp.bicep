param location string
param name string
param url string
param dbname string
param dbadmin string
param dbadminpass string
param webappClientId string
@secure()
param webappClientSecret string
param keyvault object
param tz string
param farmId string

var dbURL2 = environment().suffixes.sqlServerHostname

resource intuneWeb 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  properties: {
    serverFarmId: farmId
    httpsOnly: true
    siteConfig: {
      webSocketsEnabled: true
      alwaysOn: false
      linuxFxVersion: 'COMPOSE|dmVyc2lvbjogIjMuOCIKCnNlcnZpY2VzOgoKICB3ZWI6CiAgICBpbWFnZTogZ2hjci5pby9hbG1lbnNjb3JuZXIvaW50dW5lY2QtbW9uaXRvcjpsYXRlc3QKICAgIHJlc3RhcnQ6IGFsd2F5cwogICAgZW50cnlwb2ludDogLi9zZXJ2ZXItZW50cnlwb2ludC5zaAogICAgZXhwb3NlOgogICAgICAtIDgwODA6ODA4MAogICAgdm9sdW1lczoKICAgICAgLSAke1dFQkFQUF9TVE9SQUdFX0hPTUV9L2RiOi9pbnR1bmVjZC9kYgogICAgICAtICR7V0VCQVBQX1NUT1JBR0VfSE9NRX0vZG9jdW1lbnRhdGlvbjovZG9jdW1lbnRhdGlvbgoKICByZWRpczoKICAgIGltYWdlOiBnaGNyLmlvL2FsbWVuc2Nvcm5lci9pbnR1bmVjZC1tb25pdG9yL3JlZGlzOmxhdGVzdAogICAgcmVzdGFydDogYWx3YXlzCgogIHdvcmtlcjoKICAgIGltYWdlOiBnaGNyLmlvL2FsbWVuc2Nvcm5lci9pbnR1bmVjZC1tb25pdG9yL3dvcmtlcjpsYXRlc3QKICAgIHJlc3RhcnQ6IGFsd2F5cwogICAgZW50cnlwb2ludDogY2VsZXJ5CiAgICBjb21tYW5kOiAtQSBhcHAuY2VsZXJ5IHdvcmtlciAtbCBpbmZvCiAgICBkZXBlbmRzX29uOgogICAgICAtICJyZWRpcyIKICAgIHZvbHVtZXM6CiAgICAgIC0gJHtXRUJBUFBfU1RPUkFHRV9IT01FfS9kYjovaW50dW5lY2QvZGIKICAgICAgLSAke1dFQkFQUF9TVE9SQUdFX0hPTUV9L2RvY3VtZW50YXRpb246L2RvY3VtZW50YXRpb24KCiAgYmVhdDoKICAgIGltYWdlOiBnaGNyLmlvL2FsbWVuc2Nvcm5lci9pbnR1bmVjZC1tb25pdG9yL2JlYXQ6bGF0ZXN0CiAgICByZXN0YXJ0OiBhbHdheXMKICAgIGVudHJ5cG9pbnQ6IGNlbGVyeQogICAgY29tbWFuZDogLUEgYXBwLmNlbGVyeSBiZWF0IC1TIHNxbGFsY2hlbXlfY2VsZXJ5X2JlYXQuc2NoZWR1bGVyczpEYXRhYmFzZVNjaGVkdWxlciAtbCBpbmZvCiAgICBkZXBlbmRzX29uOgogICAgICAtICJ3b3JrZXIiCiAgICB2b2x1bWVzOgogICAgICAtICR7V0VCQVBQX1NUT1JBR0VfSE9NRX0vZGI6L2ludHVuZWNkL2RiCiAgICAgIC0gJHtXRUJBUFBfU1RPUkFHRV9IT01FfS9kb2N1bWVudGF0aW9uOi9kb2N1bWVudGF0aW9uCiAgCiAgbmdpbng6CiAgICBpbWFnZTogZ2hjci5pby9hbG1lbnNjb3JuZXIvaW50dW5lY2QtbW9uaXRvci9uZ2lueDpsYXRlc3QKICAgIHJlc3RhcnQ6IGFsd2F5cwogICAgY29tbWFuZDogWyIvYmluL3NoIiwgIi1jIiwgImVudnN1YnN0IDwgL2V0Yy9uZ2lueC9jb25mLmQvbmdpbnguY29uZi50ZW1wbGF0ZSA+IC9ldGMvbmdpbngvY29uZi5kL25naW54LmNvbmYgJiYgZXhlYyBuZ2lueCAtZyAnZGFlbW9uIG9mZjsnIl0KICAgIHBvcnRzOgogICAgICAtIDgwOjgw'
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://ghcr.io'
        }
        {
          name:'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'true'
        }
        {
          name: 'SERVER_NAME'
          value: url
        }
        {
          name: 'REDIRECT_PATH'
          value: '/auth/signin-oidc'
        }
        {
          name:'ADMIN_ROLE'
          value: 'intunecd_admin'
        }
        {
          name:'AZDBDRIVER'
          value: '{ODBC Driver 17 for SQL Server}'
        }
        {
          name:'AZDBNAME'
          value: dbname
        }
        {
          name:'AZDBUSER'
          value: dbadmin
        }
        {
          name:'AZDBPW'
          value: dbadminpass
        }
        {
          name:'AZDBSERVER'
          value:'${dbname}${dbURL2}'
        }
        {
          name:'AZURE_TENANT_ID'
          value: subscription().tenantId
        }
        {
          name:'AZURE_CLIENT_ID'
          value: webappClientId
        }
        {
          name:'AZURE_CLIENT_SECRET'
          value: webappClientSecret
        }
        {
          name:'AZURE_VAULT_URL'
          value: keyvault.properties.vaultUri
        }
        {
          name:'BEAT_DB_URI'
          value: 'sqlite:///db/schedule.db'
        }
        {
          name:'SCOPE'
          value: '[[]'
        }
        {
          name:'SECRET_KEY'
          value: resourceGroup().id
        }
        {
          name:'SESSION_LIFETIME_HOURS'
          value: ''
        }
        {
          name:'TIMEZONE'
          value: tz
        }
      ]
    }
  }
}
