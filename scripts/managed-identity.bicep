// managed-identity.bicep
// Phase 2 Task 2.2.1 - User-assigned managed identity for ADF FinOps pipelines
// Target RG: EsDAICoE-Sandbox | Location: canadacentral

param identityName string = 'mi-finops-adf'
param location string = 'canadacentral'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

output principalId string = managedIdentity.properties.principalId
output clientId string = managedIdentity.properties.clientId
output resourceId string = managedIdentity.id
output identityName string = managedIdentity.name
