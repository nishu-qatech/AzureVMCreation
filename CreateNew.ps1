$resourceGroup = "nishuazurevm"
$location = "Sweden Central"
$vmName = "nishuazurevm"
$image = "Win2022Datacenter"
$size = "Standard_B2s"
$adminUsername = "adminuser"
$password = ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($adminUsername, $password)
 
New-AzResourceGroup -Name $resourceGroup -Location $location
 
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroup `
                             -Location $location `
                             -Name "MyVNet" `
                             -AddressPrefix "10.0.0.0/16"
 
$subnet = Add-AzVirtualNetworkSubnetConfig -Name "MySubnet" `
                                           -AddressPrefix "10.0.0.0/24" `
                                           -VirtualNetwork $vnet
 
$vnet | Set-AzVirtualNetwork
 
$subnetId = (Get-AzVirtualNetwork -ResourceGroupName $resourceGroup -Name "MyVNet").Subnets[0].Id
 
$publicIP = New-AzPublicIpAddress -ResourceGroupName $resourceGroup `
                                  -Location $location `
                                  -Name "MyPublicIP" `
                                  -AllocationMethod Static
 
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup `
                                  -Location $location `
                                  -Name "MyNSG"
 
$nsgRule = New-AzNetworkSecurityRuleConfig -Name "AllowRDP" `
                                           -Protocol "Tcp" `
                                           -Direction "Inbound" `
                                           -Priority 1000 `
                                           -SourceAddressPrefix "*" `
                                           -SourcePortRange "*" `
                                           -DestinationAddressPrefix "*" `
                                           -DestinationPortRange "3389" `
                                           -Access "Allow"
 
$nsg | Add-AzNetworkSecurityRuleConfig -Name "AllowRDP" `
                                       -Protocol "Tcp" `
                                       -Direction "Inbound" `
                                       -Priority 1000 `
                                       -SourceAddressPrefix "*" `
                                       -SourcePortRange "*" `
                                       -DestinationAddressPrefix "*" `
                                       -DestinationPortRange "3389" `
                                       -Access "Allow" | Set-AzNetworkSecurityGroup
 
$nic = New-AzNetworkInterface -ResourceGroupName $resourceGroup `
                              -Location $location `
                              -Name "MyNIC" `
                              -SubnetId $subnetId `
                              -PublicIpAddressId $publicIP.Id `
                              -NetworkSecurityGroupId $nsg.Id
 
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $size | `
            Set-AzVMOperatingSystem -Windows -ComputerName $vmName -Credential $cred | `
            Set-AzVMSourceImage -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" `
            -Skus "2022-Datacenter" -Version "latest" | `
            Add-AzVMNetworkInterface -Id $nic.Id
 
New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig
 
Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName

# Output the public IP address
$publicIpAddress = $publicIP.IpAddress
Write-Output "Public IP address: $publicIpAddress"

# Convert SecureString password to plain text
$plainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
)

# Store credentials in Windows Credential Manager
$cmdkeyCommand = "cmdkey /generic:TERMSRV/$publicIpAddress /user:$adminUsername /pass:$plainTextPassword"
Invoke-Expression $cmdkeyCommand

# Launch Remote Desktop Connection (mstsc)
Start-Process "mstsc.exe" -ArgumentList "/v:$publicIpAddress"
