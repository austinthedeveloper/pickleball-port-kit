// The Web build's home: an Azure Static Web App on the free plan (port
// ADR-116). No repo link: web.yml uploads the release's web zip with the
// app's deployment token, read at deploy time through GitHub's OIDC sign-in.
param name string = 'pickleball94'
// Static Web Apps lives in a few regions only; East US 2 is the nearest
// to the relay (East US).
param location string = 'eastus2'

resource site 'Microsoft.Web/staticSites@2023-12-01' = {
  name: name
  location: location
  tags: { project: 'pickleball-web' }
  sku: { name: 'Free', tier: 'Free' }
  properties: {
    allowConfigFileUpdates: true
    stagingEnvironmentPolicy: 'Disabled'
  }
}

output name string = site.name
output url string = 'https://${site.properties.defaultHostname}'
