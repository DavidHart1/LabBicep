param (
    [string]$identityId,
    [string]$dcVMName,
    [string]$vnetName,
    [string]$resourceGroupName
)


# Install needed modules if not already installed
if (-not (Get-Module -Name Az.Accounts -ListAvailable)) {
    Install-Module -Name Az.Accounts -Force
}
# Install needed modules if not already installed
if (-not (Get-Module -Name Az.Network -ListAvailable)) {
    Install-Module -Name Az.Network -Force
}
import-module Az.Accounts
import-module Az.Network


Connect-AzAccount -Identity -AccountId $identityId
$vNet = get-azvirtualnetwork -Name $vnetName -ResourceGroupName $resourceGroupName

$dcvm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $dcVMName
$nic = Get-AzNetworkInterface -ResourceId $dcvm.NetworkProfile.NetworkInterfaces[0].Id
$newDNSObject = @{
    DnsServers = @($nic.IpConfigurations[0].PrivateIpAddress)
}
$vNet.DhcpOptions = $newDNSObject
$vNet | Set-AzVirtualNetwork