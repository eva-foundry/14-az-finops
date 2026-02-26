// adx-cluster.bicep
// Phase 2 Task 2.1.1 - Deploy Azure Data Explorer cluster for FinOps Hub
// Target RG: EsDAICoE-Sandbox | Location: canadacentral

param clusterName string = 'marcofinopsadx'
param location string = 'canadacentral'
param skuName string = 'Dev(No SLA)_Standard_E2a_v4'
param skuCapacity int = 1  // Dev SKU requires exactly 1 instance
param databaseName string = 'finopsdb'

resource adxCluster 'Microsoft.Kusto/clusters@2023-08-15' = {
  name: clusterName
  location: location
  sku: {
    name: skuName
    tier: 'Basic'
    capacity: skuCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enableStreamingIngest: true
    enablePurge: false
    publicNetworkAccess: 'Enabled' // Phase 4: change to 'Disabled' + private endpoint
    trustedExternalTenants: []
  }
}

resource adxDatabase 'Microsoft.Kusto/clusters/databases@2023-08-15' = {
  parent: adxCluster
  name: databaseName
  location: location
  kind: 'ReadWrite'
  properties: {
    softDeletePeriod: 'P1825D' // 5 years
    hotCachePeriod: 'P31D'     // 31 days hot cache
  }
}

output clusterUri string = adxCluster.properties.uri
output clusterName string = adxCluster.name
output databaseName string = adxDatabase.name
output systemPrincipalId string = adxCluster.identity.principalId
