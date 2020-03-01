Param(
        [Parameter(Mandatory=$true)]
        $Spoke,
        [Parameter(Mandatory=$true)]
        $Identifier,
        [Parameter(Mandatory=$true)]
        $LocationPrimary,
        [Parameter(Mandatory=$true)]
        $LocationDR,
        [Parameter(Mandatory=$true)]
        $DeployFirewalls,
        [Parameter(Mandatory=$false)]
        $FirewallIP,
        [Parameter(Mandatory=$false)]
        $FirewallHubSubnetName
    )
    Write-Host "Checking DeployFirewalls variable"
    if($DeployFirewalls -eq $false){
        Write-Host "DeployFirewalls parameter is set to false, no route tables will be changed and script will exit"
        exit
    }else{
        Write-Host "DeployFirewalls is true, route tables will be updated"
    }

    $networks = @("hub","Spoke1","Spoke2","Spoke3","Spoke4","Spoke5")
    
    $firewallSubnetName = $FirewallHubSubnetName

    $RouteTemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\Nested Templates\Route Table\route.json"))
    #Create table https://blogs.msdn.microsoft.com/rkramesh/2012/02/01/creating-table-using-powershell/
    
    Write-Host "Loop through each possible network"
    
        $SpokeNetworkParamFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\parameters\$spoke.parameters.json"))

        Write-Host "Check whether $spoke file exists"
        
        if(Test-Path $SpokeNetworkParamFile){

            Write-Host "$spoke parameters file exists"

            $Subnets = (Get-Content $SpokeNetworkParamFile | ConvertFrom-Json).parameters.subnetstodeploy.value
            $NoneFwSubnets = $Subnets | Where-Object{$_.SubnetName -ne $FirewallHubSubnetIdentifier}

            Write-Host "Looping through subnets in parameter file"
            ForEach($subnet in $NoneFwSubnets){
                
                $subnetName = $subnet.SubnetName

                Write-Host "Working on subnet $subnetname"

                $routeTableName = "rt-" + $Identifier + "-" + $subnetName
                $RTRGName = "rg-" + $Identifier + "-infrastructure"

                $OtherSubnets = $subnets | Where-Object{$_.SubnetName -ne $subnetName -and $_.SubnetName -ne $FirewallHubSubnetIdentifier}
                $routeTable = Get-AzRouteTable -ResourceGroupName $RTRGName -Name $routeTableName

                ForEach($OtherSubnet in $OtherSubnets){
                    $OtherSubnetName = $OtherSubnet.SubnetName
                    $OtherSubnetAddressRange = $OtherSubnet.subnetAddressRange
                    $routename = "R-" + $OtherSubnetName

                    Write-Host "Adding $routename to $routetablename in $rtrgname. Address prefix $othersubnetaddressrange, to $firewallip"

                    $NewRouteTableConfig = Add-AzRouteConfig -Name $routeName -AddressPrefix $OtherSubnetAddressRange -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIP -RouteTable $routeTable
                }
                
                $othernetworks = $networks | Where-Object{$_ -ne $spoke -and $_ -ne "hub"}

                ForEach($OtherNetwork in $OtherNetworks){
                    $OtherNetworkParamFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\parameters\$othernetwork.networking.parameters.json"))
        
                    Write-Host "Checking $othernetwork exists"
        
                    if(Test-Path $OtherNetworkParamFile){
                        Write-Host "File for $othernetwork exists"
        
                        $OtherNetworkAddressRange = (Get-Content $OtherNetworkParamFile | convertfrom-json).parameters.vnetaddressrange.value

                        $routeName = "R-" + $othernetwork

                        $NewRouteTableConfig = Add-AzRouteConfig -Name $routeName -AddressPrefix $OtherNetworkAddressRange -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIP -RouteTable $routeTable
        
                    }else{
                        Write-Host "File for $othernetworkparamfile does not exists"
                    }
                }

                $NewRouteTableConfig = Add-AzRouteConfig -Name "R-Default" -AddressPrefix "0.0.0.0/0" -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIP -RouteTable $routeTable

                $NewRouteTableConfig | Set-AzRouteTable
            
                #New-AzResourceGroupDeployment -TemplateFile $RouteTemplateFile -ResourceGroupName $RTRGName -FirewallIP $FirewallIP -Location $Location -routetablename $routeTableName -RouteNames $routeNameArray -RoutePrefixes $addressPrefixArray
            }
        

        <#
            if($spoke -eq "hub"){

            }
                    
        }

        $HubNetworkParamFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\parameters\hub.virtualnetworks.parameters.json"))
        
        
        #Add hub ranges (exluding firewall) to range list
        Write-Host "Check and add hub ranges (exluding firewall range) to range array"

        $NoneFirewallHubRanges = (Get-Content $HubNetworkParamFile | convertfrom-json).parameters.subnetstodeploy.value | Where-Object {$_.subnetName -ne $firewallSubnetName } 

        ForEach($range in $NoneFirewallHubRanges){
            $subnetAddressRange = $range.subnetAddressRange

            $ranges += $subnetAddressRange
        }

        Write-Host "Check and add ranges of other virtual networks"
        
        $OtherNetworks = $networks | Where-Object{$_ -ne $Spoke}
        
        ForEach($OtherNetwork in $OtherNetworks){
            $OtherNetworkParamFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\parameters\$othernetwork.virtualnetworks.parameters.json"))

            Write-Host "Checking $othernetwork"

            if(Test-Path $OtherNetworkParamFile){
                Write-Host "File for $spoke exists"

                (Get-Content $HubNetworkParamFile | convertfrom-json).parameters.subnetstodeploy.value

            }
            
            
            $services = (Get-Content $HubNetworkParamFile | convertfrom-json).parameters.subnetstodeploy.value
            #>
        }

        
<#
        ForEach($OtherNetwork in $OtherNetworks){
            $OtherNetworkParamFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\parameters\$othernetwork.virtualnetworks.parameters.json"))

            $services = (Get-Content $HubNetworkParamFile | convertfrom-json).parameters.vnetaddressrange.value
        }


        if($spoke -eq "hub"){

        }elseif($network -eq $Spoke){

        }else{
            
            Write-Host "Checking whether virtual network template file for $spoke ($spokeVMsparamfile) exists"
                
                if(Test-Path $SpokeVMsParamFile){
                    Write-Host "Virtual network parameters file for $spoke exists."

                    $services = (Get-Content $spokeVMsparamfile | convertfrom-json).parameters.services.value
                }
        
        }

        
    }

#>