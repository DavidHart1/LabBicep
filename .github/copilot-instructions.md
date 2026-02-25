# Copilot Instructions for LabBicep

## Repository Overview

LabBicep is a collection of Azure Bicep templates that automatically deploy a Microsoft security lab environment in Azure. It is designed to work alongside a Microsoft 365 tenant that has been pre-populated with users and content.

The environment deploys:
- Virtual Network with multiple subnets (Untrusted, Trusted, Windows-VM, Container, Gateway)
- OPNSense firewall (FreeBSD-based NVA) with two NICs for routing
- Domain Controller (Windows Server 2022) configured via PowerShell DSC
- Windows 11 VMs: one AD-joined, one Entra ID–joined, one admin/jump box
- Azure SQL Server and databases (for Purview and IntuneCD)
- IntuneCD Monitor (web app + Entra app registration) for Intune CI/CD management
- Azure Key Vault with secrets
- Log Analytics Workspace and Microsoft Sentinel (optional)
- Azure Automation Account
- Azure App Gallery with VM gallery applications (Cloud Sync, Entra Private Network Connector)
- Storage Account for artifacts/blobs
- Entra ID configuration via Microsoft Graph Bicep extension

## Repository Structure

```
/
├── azuredeploy.bicep          # Main entry-point template; orchestrates all resources
├── bicepconfig.json           # Bicep configuration; registers microsoftgraph extensions (v1.0 and beta)
├── main.bicep                 # (empty placeholder)
├── readme.md
├── .gitignore                 # Excludes azuredeploy.bicepparam and azuredeploy.parameters.json
├── Scripts/                   # PowerShell scripts executed by Azure deployment scripts and VM extensions
│   ├── AADSetup.ps1           # Provisions AD users from Entra ID via MS Graph
│   ├── ConfigureDC.ps1        # DSC configuration for Active Directory domain controller
│   ├── ConfigureCloudSync.ps1 # Configures Entra Cloud Sync on the DC
│   ├── DCSetupOrchestrator.ps1# Orchestrates post-DC-provisioning steps
│   ├── EntraConfig.ps1        # Creates users/groups in Entra ID pre-deployment
│   ├── Get-PsExec.ps1         # Helper to fetch PsExec
│   ├── IntuneAppPassword.ps1  # Creates a client secret for the IntuneCD Entra app
│   ├── SentinelSetup.ps1      # Configures Microsoft Sentinel
│   └── SetVnetDNS.ps1         # Updates VNet DNS to point to the DC after it is provisioned
└── SubTemplates/
    ├── WindowsVM.bicep         # Domain Controller VM (Windows Server 2022 + DSC + custom script ext)
    ├── VM/
    │   ├── opnsense.bicep      # OPNSense firewall VM (FreeBSD)
    │   └── windows11-vm.bicep  # Windows 11 VM with optional AD join or Entra join
    ├── accessories/
    │   ├── AppRole.bicep       # Assigns MS Graph app roles to a managed identity (uses graphV1 extension)
    │   ├── AzAuto.bicep        # Azure Automation Account
    │   ├── AzPrincipal.bicep   # Creates a user-assigned managed identity
    │   ├── CopyFile.bicep      # Deployment script to copy a file from GitHub to a storage blob
    │   ├── EntraGroup.bicep    # Creates an Entra ID security group (uses graphV1 extension)
    │   └── keyvault.bicep      # Azure Key Vault with optional secrets
    ├── intune/
    │   ├── IntuneCD.bicep      # Entra app registration + service principal for IntuneCD
    │   └── IntuneWebApp.bicep  # Azure App Service web app for IntuneCD
    ├── resourcegroup/
    │   └── rg.bicep            # Resource group (subscription-scope deployment)
    └── vnet/
        ├── nic.bicep           # Network Interface Card
        ├── nsg.bicep           # Network Security Group
        ├── publicip.bicep      # Public IP address
        ├── routetable.bicep    # Route table
        ├── routetableroutes.bicep # Route table routes
        ├── subnet.bicep        # Subnet
        └── vnet.bicep          # Virtual Network
```

## Key Design Patterns

### Bicep Extensions (Microsoft Graph)
`bicepconfig.json` registers two Bicep extensions:
- `graphV1` → `br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:1.0.0`
- `graphBeta` → `br:mcr.microsoft.com/bicep/extensions/microsoftgraph/beta:1.0.0`

Any Bicep file that manages Entra ID resources (app registrations, service principals, app role assignments, groups) must declare the extension at the top:
```bicep
extension graphV1
// or
extension graphBeta
```
The main `azuredeploy.bicep` declares both at the top.

### Naming Convention
- Resources are named using a `namePrefix` parameter (2–5 chars) combined with a descriptive suffix, e.g., `${namePrefix}-DC01`, `${namePrefix}-law01`.
- Globally unique names (storage accounts) also include a `randomString` parameter.
- Module deployment names typically prepend `${deployment().name}-` to avoid conflicts.

### Conditional Provisioning
Most major components are gated by boolean parameters:
- `provisionDC bool` — Domain Controller
- `provisionOPNSense bool` — OPNSense firewall
- `provisionSentinel bool` — Log Analytics + Sentinel
- `provisionWindowsVM { provision: bool, ... }` — AD-joined Windows 11 VM
- `provisionEntraWindowsVM { provision: bool, ... }` — Entra-joined Windows 11 VM
- `azSQL { provision: bool, ... }` — Azure SQL
- `intune { provision: bool, ... }` — IntuneCD web app

### Parameters File
The parameter file (`azuredeploy.bicepparam` or `azuredeploy.parameters.json`) is **gitignored** as it contains secrets. Never commit parameter files. Required parameters include:
- `localAdminName`, `localAdminPassword` — local VM admin
- `AzAdminName`, `AzAdminPassword` — Azure admin account
- `adUserPassword` — password for provisioned AD users
- `namePrefix` — short (2–5 char) prefix for all resource names
- `dcPrincipalName` — name of a pre-existing user-assigned managed identity with `User.Read.All` in Entra
- `dcForestName` — AD forest FQDN (e.g., `contoso.local`)
- `randomString` — suffix for globally unique names
- `usersToProvision` — array of user objects to create in Entra/AD
- `virtualNetwork` — object describing VNet provisioning options

### Managed Identities and RBAC
The deployment makes heavy use of user-assigned managed identities for automation:
- `dcPrincipal` — accesses Entra ID (User.Read.All, Directory.ReadWrite.All, etc.) from the DC
- `saPrincipal` — copies blobs to the storage account
- `kvAdminPrincipal` — manages Key Vault secrets (Key Vault Administrator role)
- `vnetPrincipal` — updates VNet DNS (Contributor + VM Contributor roles)
- `sentinelPrincipal` — configures Sentinel (Sentinel Contributor role)

### Deployment Order Dependencies
The deployment has strict ordering requirements:
1. Storage Account → blob uploads (DSC zip, scripts, agent installers)
2. Blob uploads → DC VM creation (DSC config and custom script extensions reference blobs)
3. Entra deployment script (user provisioning) → DC VM creation
4. DC VM creation → VNet DNS update script
5. VNet DNS update → AD-joined Windows 11 VM (so it can find the domain)
6. App Gallery + blob uploads → VM gallery applications → DC VM (gallery apps installed via `applicationProfile`)
7. `AADCAgentBlob` → `dcPrincipalAppRole` (timing workaround documented in code)

### Artifact Blobs
Pre-built artifacts (DSC zip, agent installers, scripts) are sourced from `https://github.com/HartD92/LabBicepArtifacts/raw/main/Blobs/` and copied to the deployment storage account via `CopyFile.bicep` deployment scripts. These blobs are referenced using SAS tokens generated at deploy time.

## How to Deploy

### Prerequisites
1. Accept the FreeBSD license for OPNSense:
   ```bash
   az vm image terms accept --urn thefreebsdfoundation:freebsd-14_1:14_1-release-amd64-gen2-zfs:14.1.0 -o none
   ```
2. Compile the DSC configuration if changed:
   ```powershell
   Install-Module az,xStorage,xActiveDirectory,xNetworking,PSDesiredStateConfiguration,xPendingReboot
   Import-Module Az
   Publish-AzVMDscConfiguration .\Scripts\ConfigureDC.ps1 -OutputArchivePath .\ConfigureDC.zip
   ```
3. Create and populate a Bicep param file (`azuredeploy.bicepparam`).

### Deploy
```bash
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file azuredeploy.bicep \
  --parameters azuredeploy.bicepparam
```

### Validate (lint/build)
There is no CI pipeline in this repository. To validate Bicep locally:
```bash
az bicep build --file azuredeploy.bicep
```
This requires the [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) or [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) with the Bicep extension.

To lint:
```bash
az bicep lint --file azuredeploy.bicep
```

## Known Issues and Workarounds

- **OPNSense routing**: Setting `provisionOPNSense: false` skips firewall provisioning but does not correctly adjust the route table or NSG (tracked with a `// Right Now this only skips...` comment).
- **Windows VM domain join timing**: The AD-joined Windows 11 VM (`winvm1`) depends on `vnetDnsUpdateScript`, which updates VNet DNS to point to the DC. Without this, the VM cannot resolve the domain during join.
- **DC provisioning delay for app role assignment**: `dcPrincipalAppRole` explicitly `dependsOn: [AADCAgentBlob]` as a workaround to add a delay before assigning app roles, preventing a race condition where the managed identity principal is not yet visible in Entra.
- **`#disable-next-line secure-secrets-in-params`**: Used in `windows11-vm.bicep` to suppress the Bicep linter warning about passing passwords as plain string parameters. This is an intentional trade-off in the template design.
- **Key Vault soft delete**: The inline `kv` resource in `azuredeploy.bicep` sets `enableSoftDelete: false` to allow redeployment without purge operations.
- **`main.bicep` is empty**: The actual entry point is `azuredeploy.bicep`. `main.bicep` is a placeholder.
- **Graph extension timing**: The Microsoft Graph Bicep extension requires the Entra tenant to be accessible at deploy time. Deployments that create Entra resources (app registrations, app role assignments) can fail if the tenant has conditional access policies or if the deployment principal lacks sufficient Graph permissions.
- **`dcForestName` placement**: The `dcForestName` parameter is declared after variables that reference it (line ~73 in `azuredeploy.bicep`). This is valid in Bicep but non-standard; keep new parameters near the top of the file.

## Coding Conventions

- Use `camelCase` for variable and parameter names; resource symbolic names also use camelCase.
- Use `PascalCase` for Bicep module names and some legacy parameter names (e.g., `Location`, `TempPassword`).
- Use object-typed parameters for grouped settings (e.g., `provisionWindowsVM`, `azSQL`, `intune`).
- Annotate parameters with `@description(...)`, `@minLength(...)`, `@maxLength(...)`, and `@secure()` as appropriate.
- Use `@sys.description(...)` for parameters in files that also use the `graphV1`/`graphBeta` extensions (avoids ambiguity with Graph `description` keyword).
- Secrets passed to VMs should use `@secure()` and `protectedSettings` in extensions.
- Use `loadTextContent('./Scripts/ScriptName.ps1')` to embed PowerShell scripts inline in deployment scripts.
- Module names in `azuredeploy.bicep` often prepend `${deployment().name}-` to scope deployment names per deployment.
