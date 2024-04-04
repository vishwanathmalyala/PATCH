param location string = 'westus3'
param vmName string = 'dev-vm'
param adminUsername string = 'admin-username'
param adminPassword string ='admin@123'
param sqlServerName string = 'sql-dev-server'
param databaseName string = 'dev-database'
param storageAccountName string = 'dev-storage-account'

resource vnet 'Microsoft.Network/virtualNetworks@2021-04-01' = {
  name: 'dev-vNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
}

resource webSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-04-01' = {
  parent: vnet
  name: 'webSubnet'
  properties: {
    addressPrefix: '10.0.1.0/24'
  }
}

resource dbSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-04-01' = {
  parent: vnet
  name: 'dbSubnet'
  properties: {
    addressPrefix: '10.0.2.0/24'
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-04-01' = {
  name: 'dev-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
        }
      }
      {
        name: 'AllowSql'
        properties: {
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '1433'
          access: 'Allow'
          direction: 'Inbound'
          priority: 101
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: vmName
  location: location
  dependsOn: [
    nsg
  ]
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS2_v2'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}
resource publicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: 'dev_public_ip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2021-04-01' = {
  name: 'dev-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: webSubnet
          publicIPAddress: publicIP
        }
      }
    ]
  }
}

resource sqlServer 'Microsoft.Sql/servers@2019-06-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    version: '12.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2019-06-01-preview' = {
  name: '${sqlServerName}/${databaseName}'
  location: location
  dependsOn: [
    sqlServer
  ]
  properties: {
    edition: 'Standard'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 1073741824 // 1GB
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: 'dev-law'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    workspaceCapping: {
      dailyQuotaGb: '0.023'
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'dev-ai'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

output vmPublicIp string = vm.properties.networkProfile.networkInterfaces[0].properties.ipConfigurations[0].properties.publicIPAddress.properties.ipAddress

