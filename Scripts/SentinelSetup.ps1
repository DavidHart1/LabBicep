param (
    [string]$subscriptionId,
    [string]$ManagedIdentityClientId,
    [string]$resourceGroupName = "HLA-Azure",
    [string]$workspaceName = "hla-law01",
    [hashtable]$solutionsToDeploy = @{
        "EntraID" = "azuresentinel.azure-sentinel-solution-azureactivedirectory"
        "AzureActivity" = "azuresentinel.azure-sentinel-solution-azureactivity"
        "M365Defender" = "azuresentinel.azure-sentinel-solution-microsoft365defender"
        "DforCloud" = "azuresentinel.azure-sentinel-solution-microsoftdefenderforcloud"
        "NetworkSession" = "azuresentinel.azure-sentinel-solution-networksession"
        "SecThreatEssential" = "azuresentinel.azure-sentinel-solution-securitythreatessentialsol"
        "SOAREssential" = "azuresentinel.azure-sentinel-solution-sentinelsoaressentials"
        "ThreatIntel" = "azuresentinel.azure-sentinel-solution-threatintelligence-taxii"
        "UEBA" = "azuresentinel.azure-sentinel-solution-uebaessentials"
        "SOCHandbook" = "microsoftsentinelcommunity.azure-sentinel-solution-sochandbook"
    }
)

$apiVersion = "2023-06-01-preview"
$resourceProvider = "Microsoft.OperationalInsights"

# Install needed modules if not already installed
if (-not (Get-Module -Name Az.Accounts -ListAvailable)) {
    Install-Module -Name Az.Accounts -Force
}

# Import Required Modules
import-module Az.Accounts

# Connect to Azure and setup the token
Connect-AzAccount -Identity -AccountId $ManagedIdentityClientId
set-azcontext -subscription $subscriptionId
$context = Get-AzContext
$azprofile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
$profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azprofile)
function Get-AzureToken {
    param (
        [Microsoft.Azure.Commands.Profile.Models.Core.PSAzureContext] $context,
        [Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient] $profileClient
    )
    $token = $profileClient.AcquireAccessToken($context.Subscription.TenantId)
    $authHeader = @{
        'Content-Type' = 'application/json' 
        'Authorization' = 'Bearer ' + $token.AccessToken 
    }
    return $authHeader
}
function Read-RestResult {
    param (
        [string]$uri,
        [hashtable]$authHeader
    )
    $result = (invoke-restmethod -method "Get" -uri $uri -Headers $authHeader)
    if ($null -ne $result.value) {
        return $result.value
    }
    else {
        return $result
    }
}
function Send-RestResult {
    param (
        [string]$uri,
        [hashtable]$authHeader,
        [hashtable]$body
    )
    $result =(invoke-restmethod -method "Put" -uri $uri -Headers $authHeader -body ($body | ConvertTo-Json -Depth 10 -EnumsAsStrings))
    if ($null -ne $result.value) {
        return $result.value
    }
    else {
        return $result
    }
}

$authHeader = Get-AzureToken -context $context -profileClient $profileClient
# Setup base URL for Sentinel
$azureurl = "https://management.azure.com"
$baseurl = $azureurl + "/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroupName + "/providers/" 
$sentinelbaseurl = $baseurl + $resourceprovider + "/workspaces/" + $workspaceName + "/providers/Microsoft.SecurityInsights/"
# Get Sentinel cases
$apiVersion = "2019-01-01-preview"
$uri = $sentinelbaseurl + "cases?api-version=" + $apiVersion
$results = Read-RestResult -uri $uri -authHeader $authHeader
$apiVersion = "2023-06-01-preview"
$uri = $sentinelbaseurl + "contentPackages?api-version=" + $apiVersion
$results = Read-RestResult -uri $uri -authHeader $authHeader

$results = @{}
$apiVersion = "2023-06-01-preview"
$uri = $sentinelbaseurl + "contentProductPackages?expand=properties/packagedContent&api-version=" + $apiVersion
$productCatalog = Read-RestResult -uri $uri -authHeader $authHeader
# Deploy Sentinel solutions
foreach ($solution in $solutionsToDeploy.GetEnumerator()){
    $apiVersion = "2023-11-01-preview"
    write-host $solution.key " - " $solution.Value
    #$solutionuri = $sentinelbaseurl + "contentPackages/" + $solution.Value + "?api-version=" + $apiVersion
    $solutionInfo = $productCatalog | Where-Object {$_.properties.contentKind -eq "Solution"} | Where-Object {$_.properties.contentId -eq $solution.Value}
    $apiVersion = "2023-11-01-preview"
    $installBody = @{"properties" = @{
        "contentId" = $solutionInfo.properties.contentId
        "contentKind" = $solutionInfo.properties.contentKind
        "contentProductId" = $solutionInfo.properties.contentProductId
        "displayName" = $solutionInfo.properties.displayName
        "version" = $solutionInfo.properties.version
    }}
    #$deploymentURI = $deploymentbaseurl + $deploymentName + "?api-version=" + $apiVersion
    # Well. This install command doesn't actually work. It shows installed and doesn't DO ANYTHING. WTF?!
    # 
    $deploymentURI = $sentinelbaseurl + "contentPackages/" + $solution.Value + "?api-version=" + $apiVersion
    $results.Add(($solution.Key),(Send-RestResult -uri $deploymentURI -authHeader $authHeader -body $installBody))
}
