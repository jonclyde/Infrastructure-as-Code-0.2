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
        $FirewallHubSubnetIdentifier
    )

    Write-Host "--------------------------------"
    Write-Host "Section 0 - Pre-requisites and set variables"
    Write-Host "--------------------------------"
    $networks = @("hub","Spoke1","Spoke2","Spoke3","Spoke4","Spoke5")

    Write-Host "Checking DeployFirewalls variable"

    if($DeployFirewalls -eq $true){
        Write-Host "DeployFirewalls is true, route tables will be updated"
        
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

                $routeTableNamePrimary = "rt-pr-" + $Identifier + "-" + $subnetName
                $RTPrimaryRGName = "rg-pr-" + $Identifier + "-inf"
                $routeTablePR = Get-AzRouteTable -ResourceGroupName $RTPrimaryRGName -Name $routeTableNamePrimary


                if($DeployDR -eq $true){
                    $routeTableNameDR = "rt-dr-" + $Identifier + "-" + $subnetName
                    $RTDRRGName = "rg-dr-" + $Identifier + "-inf"
                    $routeTableDR = Get-AzRouteTable -ResourceGroupName $RTDRRGName -Name $routeTableNameDR

                }
                
                $OtherSubnets = $subnets | Where-Object{$_.SubnetName -ne $subnetName -and $_.SubnetName -ne $FirewallHubSubnetName}

                #Process per subnet routes for local primary and DR vnets
                ForEach($OtherSubnet in $OtherSubnets){
                    $OtherSubnetName = $OtherSubnet.SubnetName
                    $OtherSubnetAddressRangePR = $OtherSubnet.subnetAddressRangePrimary
                    $routenamePR = "R-PR-" + $OtherSubnetName

                    Write-Host "Add route: primary region, spoke $spoke, routename $routenamepr, addressprefix $OtherSubnetAddressRangePR, routetable $routetablenameprimary"

                    $NewRouteTableConfigPR = Add-AzRouteConfig -Name $routeNamePR -AddressPrefix $OtherSubnetAddressRangePR -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPPrimary -RouteTable $routetablePR
                    
                    if($DeployDR -eq $true){
                        $DRRange = (Get-Content $SpokeNetworkParamFile | ConvertFrom-Json).parameters.VNAddressRangeDR.value
                        $OtherSubnetAddressRangeDR = $OtherSubnet.OtherSubnetAddressRangeDR
                        $routeNameDR = "R-DR-" + $Identifier
    
                        Write-Host "Add route: DR region, spoke $spoke, routename $routenamedr, addressprefix $OtherSubnetAddressRangeDR, routetable $routetablenameDR"
                        
                        $NewRouteTableConfigDR = Add-AzRouteConfig -Name $routeNameDR -AddressPrefix $OtherSubnetAddressRangeDR -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPDR -RouteTable $routetableDR
                    }
                }

                $VNAddressRangePR
                $VNAddressRangeDR
                #
                #
                #
                #
                #lines above is where i'm up to - create routes on primary and dr vnets to route traffic for each other (entire vnet ranges)





                $othernetworks = $networks | Where-Object{$_ -ne $spoke -and $_ -ne "hub"}

                ForEach($OtherNetwork in $OtherNetworks){
                    $OtherNetworkParamFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\parameters\$othernetwork.networking.parameters.json"))
        
                    Write-Host "Checking $othernetwork exists"
        
                    if(Test-Path $OtherNetworkParamFile){
                        Write-Host "File for $othernetwork exists"
        
                        $OtherNetworkAddressRangePR = (Get-Content $OtherNetworkParamFile | convertfrom-json).parameters.VNAddressRangePrimary.value
                        $OtherNetworkAddressRangeDR = (Get-Content $OtherNetworkParamFile | convertfrom-json).parameters.VNAddressRangeDR.value

                        $routenamePR = "R-PR-" + $othernetwork
                        $routenameDR = "R-DR-" + $othernetwork

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

                Write-Host "Add route: primary region, spoke $spoke, routename R-Default, addressprefix 0.0.0.0/0, routetable $routetablenameprimary"
                #$NewRouteTableConfigPR = Add-AzRouteConfig -Name "R-Default" -AddressPrefix "0.0.0.0/0" -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPPrimary -RouteTable $routeTablePR
                
                Write-Host "Add route: DR region, spoke $spoke, routename R-Default, addressprefix 0.0.0.0/0, routetable $routetablenamedr"
                #$NewRouteTableConfigDR = Add-AzRouteConfig -Name "R-Default" -AddressPrefix "0.0.0.0/0" -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPDR -RouteTable $routeTableDR

                $NewRouteTableConfigPR | Set-AzRouteTable

                $NewRouteTableConfigDR | Set-AzRouteTable
            }

        }

        
    }else{
        Write-Host "DeployFirewalls parameter is set to false, no route tables will be changed and script will exit"
        Write-Host "--------------------------------"
        Write-Host "End"
        Write-Host "--------------------------------"
        exit
    }