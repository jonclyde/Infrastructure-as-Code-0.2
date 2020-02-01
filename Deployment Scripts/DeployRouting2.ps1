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
        $DeployDR,
        [Parameter(Mandatory=$true)]
        $DeployFirewalls,
        [Parameter(Mandatory=$false)]
        $FirewallIPPrimary,
        [Parameter(Mandatory=$false)]
        $FirewallIPDR,
        [Parameter(Mandatory=$false)]
        $FirewallHubSubnetName
    )

    Write-Host "--------------------------------"
    Write-Host "Section 0 - Pre-requisites and set variables"
    Write-Host "--------------------------------"
    $networks = @("hub","Spoke1","Spoke2","Spoke3","Spoke4","Spoke5")
    $RouteTemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\Nested Templates\Route Table\route.json"))

    Write-Host "Checking DeployFirewalls variable"

    if($DeployFirewalls -eq $true){
        Write-Host "DeployFirewalls is true, route tables will be updated"
        
        Write-Host "Loop through each possible network"
    
        $SpokeNetworkParamFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\parameters\$spoke.parameters.json"))

        Write-Host "Check whether $spoke file exists"
        
        if(Test-Path $SpokeNetworkParamFile){
            Write-Host "$spoke parameters file exists"

            $Subnets = (Get-Content $SpokeNetworkParamFile | ConvertFrom-Json).parameters.subnetstodeploy.value
            $NoneFwSubnets = $Subnets | Where-Object{$_.SubnetName -ne $FirewallHubSubnetName}

            Write-Host "Looping through subnets in parameter file"
            ForEach($subnet in $NoneFwSubnets){
                $subnetName = $subnet.SubnetName

                Write-Host "Working on subnet $subnetname"

                $routeTableNamePrimary = "rt-" + "-pr-" + $Identifier + "-" + $subnetName
                $RTPrimaryRGName = "rg-" + "-pr-" + $Identifier + "-inf"
                $routeTablePR = Get-AzRouteTable -ResourceGroupName $RTPrimaryRGName -Name $routeTableNamePrimary


                if($DeployDR -eq $true){
                    $routeTableNameDR = "rt-" + "-dr-" + $Identifier + "-" + $subnetName
                    $RTDRRGName = "rg-" + "-dr-" + $Identifier + "-inf"
                    $routeTableDR = Get-AzRouteTable -ResourceGroupName $RTDRRGName -Name $routeTableNameDR

                }
                
                $OtherSubnets = $subnets | Where-Object{$_.SubnetName -ne $subnetName -and $_.SubnetName -ne $FirewallHubSubnetName}

                ForEach($OtherSubnet in $OtherSubnets){
                    $OtherSubnetName = $OtherSubnet.SubnetName
                    $OtherSubnetAddressRangePR = $OtherSubnet.subnetAddressRangePrimary
                    $routenamePR = "R-PR-" + $OtherSubnetName

                    Write-Host "Adding $routename to $routetablename in $rtrgname. Address prefix $othersubnetaddressrangePR, to $firewallip"

                    $NewRouteTableConfigPR = Add-AzRouteConfig -Name $routeName -AddressPrefix $OtherSubnetAddressRangePR -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPPrimary -RouteTable $routenamePR
                }

                if($DeployDR -eq $true){
                    $DRRange = (Get-Content $SpokeNetworkParamFile | ConvertFrom-Json).parameters.VNAddressRangeDR.value
                    $OtherSubnetAddressRangeDR = $OtherSubnet.OtherSubnetAddressRangeDR
                    $routeNameDR = "R-DR-" + $Identifier
                    
                    $NewRouteTableConfigDR = Add-AzRouteConfig -Name $routeName -AddressPrefix $OtherSubnetAddressRangeDR -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPDR -RouteTable $routeNameDR
                }

                $othernetworks = $networks | Where-Object{$_ -ne $spoke -and $_ -ne "hub"}

                ForEach($OtherNetwork in $OtherNetworks){
                    $OtherNetworkParamFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\parameters\$othernetwork.networking.parameters.json"))
        
                    Write-Host "Checking $othernetwork exists"
        
                    if(Test-Path $OtherNetworkParamFile){
                        Write-Host "File for $othernetwork exists"
        
                        $OtherNetworkAddressRangePR = (Get-Content $OtherNetworkParamFile | convertfrom-json).parameters.VNAddressRangePrimary.value
                        $OtherNetworkAddressRangeDR = (Get-Content $OtherNetworkParamFile | convertfrom-json).parameters.VNAddressRangeDR.value

                        $routenamePR = "R-PR-" + $othernetwork
                        $routenamePR = "R-DR-" + $othernetwork

                        $NewRouteTableConfigPR = Add-AzRouteConfig -Name $routenamePR-AddressPrefix $OtherNetworkAddressRangePR -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPPrimary -RouteTable $routeTablePR
                        $NewRouteTableConfigPR = Add-AzRouteConfig -Name $routeNameDR -AddressPrefix $OtherNetworkAddressRangeDR -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPPrimary -RouteTable $routeTablePR

                        if($DeployDR -eq $true){
                            $NewRouteTableConfigDR = Add-AzRouteConfig -Name $routenamePR-AddressPrefix $OtherNetworkAddressRangePR -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPDR -RouteTable $routeTablePR
                            $NewRouteTableConfigDR = Add-AzRouteConfig -Name $routeNameDR -AddressPrefix $OtherNetworkAddressRangeDR -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPDR -RouteTable $routeTablePR
                        }
        
                    }else{
                        Write-Host "File for $othernetworkparamfile does not exists"
                    }
                }

                $NewRouteTableConfig = Add-AzRouteConfig -Name "R-Default" -AddressPrefix "0.0.0.0/0" -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIP -RouteTable $routeTable

                $NewRouteTableConfig | Set-AzRouteTable
            }

        }

        
    }else{
        Write-Host "DeployFirewalls parameter is set to false, no route tables will be changed and script will exit"
        Write-Host "--------------------------------"
        Write-Host "End"
        Write-Host "--------------------------------"
        exit
    }