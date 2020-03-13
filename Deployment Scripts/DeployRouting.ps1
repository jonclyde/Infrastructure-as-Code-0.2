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

    <#
        Routes for each subnet in the environment
        - other subnets on same vnet (configure DR vnet if applicable)
        - hub subnets in the same region, not including FW subnet
        - other vnets in primary region
        - All vnets in the secondary region
    #>

    if($DeployFirewalls -eq $true){

        Write-Host "--------------------------------"
        Write-Host "Section 1 - Configure routes"
        Write-Host "--------------------------------"
        Write-Host "DeployFirewalls is true, route tables will be updated"
    
        $SpokeNetworkParamFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\parameters\$spoke.parameters.json"))

        Write-Host "$spoke routes selected for configuration in this script, checking $spoke file exists"
        
        
        if(Test-Path $SpokeNetworkParamFile){
            Write-Host "$spoke parameters file exists"
            
            $DeployDR = (Get-Content $SpokeParamFile  | convertfrom-json).parameters.DeployDR.value
            $Subnets = (Get-Content $SpokeNetworkParamFile | ConvertFrom-Json).parameters.subnetstodeploy.value
            $NoneFwSubnets = $Subnets | Where-Object{$_.SubnetName -ne $FirewallHubSubnetIdentifier}

            Write-Host "--------------------------------"
            Write-Host "Section 1.1 - Configure routes - subnets on the same vnet (configure DR vnet if applicable)"
            Write-Host "--------------------------------"

            Write-Host "Looping through subnets on the same vnet in parameter file"
            ForEach($subnet in $NoneFwSubnets){
                $subnetName = $subnet.SubnetName

                Write-Host "<----------- Working on subnet $subnetname"

                $routeTableNamePrimary = "rt-pr-" + $Identifier + "-" + $subnetName
                $RTPrimaryRGName = "rg-pr-" + $Identifier + "-inf"
                $routeTablePR = Get-AzRouteTable -ResourceGroupName $RTPrimaryRGName -Name $routeTableNamePrimary

                "Primary route table for $subnetname : routetablename $routetablenameprimary, rtprimaryrgname $RTPrimaryRGName"
                
                if($DeployDR -eq $true){
                    $routeTableNameDR = "rt-dr-" + $Identifier + "-" + $subnetName
                    $RTDRRGName = "rg-dr-" + $Identifier + "-inf"
                    $routeTableDR = Get-AzRouteTable -ResourceGroupName $RTDRRGName -Name $routeTableNameDR

                    "DR route table for $subnetname : routetablename $routetablenameDR, rtprimaryrgname $RTDRRGName"

                }
                
                $OtherSubnets = $subnets | Where-Object{$_.SubnetName -ne $subnetName -and $_.SubnetName -notlike "*$FirewallHubSubnetIdentifier*"}

                #Process per subnet routes for local primary and DR vnets
                ForEach($OtherSubnet in $OtherSubnets){
                    $OtherSubnetName = $OtherSubnet.SubnetName
                    $OtherSubnetAddressRangePR = $OtherSubnet.subnetAddressRangePrimary
                    $OtherSubnetAddressRangeDR = $OtherSubnet.subnetAddressRangeDR
                    
                    $routeNamePRSubnet = "R-PR-" + $OtherSubnetName
                    $routeNameDRSubnet  = "R-DR-" + $OtherSubnetName

                    Write-Host "Add route (other subnet, same vnet primary): spoke $spoke, routename $routeNamePRSubnet, addressprefix $OtherSubnetAddressRangePR, routetable $routetablenameprimary"

                    $NewRouteTableConfigPR = Add-AzRouteConfig -Name $routeNamePRSubnet -AddressPrefix $OtherSubnetAddressRangePR -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPPrimary -RouteTable $routetablePR
                    
                    if($DeployDR -eq $true){
                        Write-Host "Add route (other subnet, same vnet DR): spoke $spoke, routename $routeNameDRSubnet, addressprefix $OtherSubnetAddressRangeDR, routetable $routetablenameDR"
                        
                        $NewRouteTableConfigDR = Add-AzRouteConfig -Name $routeNameDRSubnet -AddressPrefix $OtherSubnetAddressRangeDR -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPDR -RouteTable $routetableDR

                    }

                }

                Write-Host "--------------------------------"
                Write-Host "Section 1.2 - Configure routes - current vnet primary and DR routing across regions"
                Write-Host "--------------------------------"
                if($DeployDR -eq $true){
                    $PrimaryRange = (Get-Content $SpokeNetworkParamFile | ConvertFrom-Json).parameters.VNAddressRangePrimary.value
                    $DRRange = (Get-Content $SpokeNetworkParamFile | ConvertFrom-Json).parameters.VNAddressRangeDR.value
                    $routeNamePRVNet = "R-PR-" + $Identifier 
                    $routeNameDRVnet = "R-DR-" + $Identifier

                    Write-Host "Add route (for DR range, to primary route table for $subnetname): spoke $spoke, routename $routeNameDRVnet, addressprefix $DRRange, routetable $routetablenameprimary"

                    $NewRouteTableConfigPR = Add-AzRouteConfig -Name $routeNameDRVnet -AddressPrefix $DRRange -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPPrimary -RouteTable $routetablePR

                    Write-Host "Add route (for primary range, to DR route table for $subnetname): spoke $spoke, routename $routeNamePRVNet, addressprefix $PrimaryRange, routetable $routetablenameDR"

                    $NewRouteTableConfigDR = Add-AzRouteConfig -Name $routeNamePRVNet -AddressPrefix $PrimaryRange -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPDR -RouteTable $routetableDR
                }
            
                Write-Host "--------------------------------"
                Write-Host "Section 1.3 - Configure routes - routes for other vnets (configure DR if applicable)"
                Write-Host "--------------------------------"
                
                Write-Host "Getting all networks that aren't the same spoke or the hub spoke"
                $othernetworks = $networks | Where-Object{$_ -ne $spoke -and $_ -ne "hub"}

                ForEach($OtherNetwork in $OtherNetworks){
                    $OtherNetworkParamFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\parameters\$othernetwork.parameters.json"))
        
                    Write-Host "Checking $othernetwork exists"
        
                    if(Test-Path $OtherNetworkParamFile){
                        Write-Host "File for $othernetwork exists"
        
                        $OtherNetworkAddressRangePR = (Get-Content $OtherNetworkParamFile | convertfrom-json).parameters.VNAddressRangePrimary.value
                        $OtherNetworkAddressRangeDR = (Get-Content $OtherNetworkParamFile | convertfrom-json).parameters.VNAddressRangeDR.value

                        $OtherNetIdentifier = (Get-Content $OtherNetworkParamFile | ConvertFrom-Json).parameters.Identifier.value
                        
                        $routenamePR = "R-PR-" + $OtherNetIdentifier
                        $routenameDR = "R-DR-" + $OtherNetIdentifier

                        Write-Host "Add route (primary region, primary range for another spoke): spoke $spoke, routename $routenamedr, addressprefix $OtherSubnetAddressRangeDR, routetable $routetablenamePR"

                        $NewRouteTableConfigPR = Add-AzRouteConfig -Name $routenamePR -AddressPrefix $OtherNetworkAddressRangePR -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPPrimary -RouteTable $routeTablePR

                        if($DeployDR -eq $true){

                            Write-Host "Add route (primary region, DR range for another spoke): spoke $spoke, routename $routenamedr, addressprefix $OtherSubnetAddressRangeDR, routetable $routetablenamePR"
                            
                            $NewRouteTableConfigPR = Add-AzRouteConfig -Name $routeNameDR -AddressPrefix $OtherNetworkAddressRangeDR -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPPrimary -RouteTable $routeTablePR

                            Write-Host "Add route (DR region, primary range for another spoke): spoke $spoke, routename $routenamedr, addressprefix $OtherSubnetAddressRangeDR, routetable $routetablenameDR"

                            $NewRouteTableConfigDR = Add-AzRouteConfig -Name $routenamePR -AddressPrefix $OtherNetworkAddressRangePR -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPDR -RouteTable $routeTableDR
                            
                            Write-Host "Add route (DR region, DR range for another spoke): spoke $spoke, routename $routenamedr, addressprefix $OtherSubnetAddressRangeDR, routetable $routetablenameDR"

                            $NewRouteTableConfigDR = Add-AzRouteConfig -Name $routeNameDR -AddressPrefix $OtherNetworkAddressRangeDR -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPDR -RouteTable $routeTableDR
                        }
        
                    }else{
                        Write-Host "File for $othernetworkparamfile does not exists"
                    }
                }

                Write-Host "Add route (primary region, internet traffic): spoke $spoke, routename R-Default, addressprefix 0.0.0.0/0, routetable $routetablenameprimary"

                $NewRouteTableConfigPR = Add-AzRouteConfig -Name "R-Default" -AddressPrefix "0.0.0.0/0" -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPPrimary -RouteTable $routeTablePR
                
                Write-Host "Add route (DR region, internet traffic): spoke $spoke, routename R-Default, addressprefix 0.0.0.0/0, routetable $routetablenamedr"
                
                if($DeployDR -eq $true)
                {
                    $NewRouteTableConfigDR = Add-AzRouteConfig -Name "R-Default" -AddressPrefix "0.0.0.0/0" -NextHopType "VirtualAppliance" -NextHopIpAddress $FirewallIPDR -RouteTable $routeTableDR
                }

                "PR final route table for $subnetname"

                $NewRouteTableConfigPR | Set-AzRouteTable
                
                "DR final route table for $subnetname"
                $NewRouteTableConfigDR | Set-AzRouteTable
            }

        }
        else{
            Write-Host "$spoke ($SpokeNetworkParamFile) parameters file doesn't exist. Script will be terminated"
            Write-Host "--------------------------------"
            Write-Host "End"
            Write-Host "--------------------------------"
            exit
        }

        
    }else{
        Write-Host "DeployFirewalls parameter is set to false, no route tables will be changed and script will exit"
        Write-Host "--------------------------------"
        Write-Host "End"
        Write-Host "--------------------------------"
        exit
    }