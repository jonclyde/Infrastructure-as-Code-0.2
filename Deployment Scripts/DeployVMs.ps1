Param(
        [Parameter(Mandatory=$true)]
        $Spoke,
        [Parameter(Mandatory=$true)]
        $Identifier,
        [Parameter(Mandatory=$true)]
        $DeployType,
        [Parameter(Mandatory=$true)]
        $NameforKeyVault,
        [Parameter(Mandatory=$true)]
        $RGNameforKeyVault,
        [Parameter(Mandatory=$true)]
        $DeployFW,
        [Parameter(Mandatory=$true)]
        $DeployDR,
        [Parameter(Mandatory=$true)]
        $FirewallHubSubnetName,
        [Parameter(Mandatory=$true)]
        $FirewallHubSubnetRangePrimary,
        [Parameter(Mandatory=$true)]
        $FirewallHubSubnetRangeDR,
        [Parameter(Mandatory=$true)]
        $DefaultVMSize,
        [Parameter(Mandatory=$true)]
        $LocationPrimary,
        [Parameter(Mandatory=$true)]
        $LocationDR,
        [Parameter(Mandatory=$true)]
        $DefaultUsername,
        [Parameter(Mandatory=$true)]
        $AutomationRG,
        [Parameter(Mandatory=$true)]
        $NameEncryptKey
    )
    Write-Host "--------------------------------"
    Write-Host "Section 0 - Pre-requisites and set variables"
    Write-Host "--------------------------------"
    $BarracudaTemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\nested templates\Barracuda CGF\barracuda.json"))
    $CentralParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\Parameters\central.parameters.json"))
    $VMsParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\parameters\$Spoke.parameters.json"))
    $VMTemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\Master Templates\Virtual Machine Service\vmservice.json"))
    $DSCTemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\Nested Templates\VM Extensions\PowerShell DSC\dscconfiguration.json"))
    #$BackupTemplatefile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\Nested Templates\Recovery Services Vault\protectvm.json"))
    $AntimalwareTemplatefile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\Nested Templates\VM Extensions\Microsoft Antimalware\microsoftantimalware.json"))
    $LogAnalyticsTemplatefile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\Nested Templates\VM Extensions\Log Analytics\loganalytics.json"))

    if($DeployType -eq "firewall" -and $spoke -ne "hub"){
        Write-Host "Parameters are invalid. Deploy type is firewall but spoke is not set to hub"
        Write-Host "Deploy type - $DeployType"
        Write-Host "Spoke - $spoke"
        Write-Host "--------------------------------"
        Write-Host "End"
        Write-Host "--------------------------------"
    }
    Write-Host "Checking value of the deploy type parameter"

    Write-Host "--------------------------------"
    Write-Host "Section 0 - Deploy Virtual Machines"
    Write-Host "--------------------------------"

    if($DeployType -eq "Firewall"){
        
        if($DeployFW -eq $true){

            
            Write-Host "DeployFW parameter is set to true. Primary firewalls will now be deployed"

            $FWRGNamePrimary = "rg-pr-" + $identifier + "-fw"
            $FWVNRGPrimary = "rg-pr-" + $identifier + "-inf"
            $EnvironmentIdentifier = "pr"

            New-AzResourceGroup -Name $FWRGNamePrimary -Location $LocationPrimary -Force

            New-AzResourceGroupDeployment -TemplateFile $BarracudaTemplateFile `
                                          -ResourceGroupName $FWRGNamePrimary `
                                          -Identifier $Identifier `
                                          -VNFirewallRG $FWVNRGPrimary `
                                          -EnvironmentIdentifier $EnvironmentIdentifier `
                                          -FirewallHubSubnetName $FirewallHubSubnetName `
                                          -FirewallHubSubnetRange $FirewallHubSubnetRangePrimary `
                                          -VMSize $DefaultVMSize `
                                          -NameforKeyVault $NameforKeyVault `
                                          -RGNameforKeyVault `


            if($DeployDR -eq $true){

                Write-Host "DeployDR parameter is set to true. Primary firewalls will now be deployed"

                $FWRGNameDR = "rg-dr-" + $identifier + "-fw"
                $FWVNRGDR = "rg-dr-" + $identifier + "-inf"
                $EnvironmentIdentifier = "dr"

                New-AzResourceGroup -Name $FWRGNameDR -Location $LocationDR -Force

                New-AzResourceGroupDeployment -TemplateFile $BarracudaTemplateFile `
                                            -ResourceGroupName $FWRGNameDR `
                                            -Identifier $Identifier `
                                            -VNFirewallRG $FWVNRGDR `
                                            -EnvironmentIdentifier $EnvironmentIdentifier `
                                            -FirewallHubSubnetName $FirewallHubSubnetName `
                                            -FirewallHubSubnetRange $FirewallHubSubnetRangeDR `
                                            -VMSize $DefaultVMSize `
                                            -NameforKeyVault $NameforKeyVault `
                                            -RGNameforKeyVault `
            }

         }
         else{
             Write-Host "Deploy firewall is set to false. No firewalls will be deployed"
             Write-Host "--------------------------------"
             Write-Host "End"
             Write-Host "--------------------------------"
             exit
         }
    }elseif($DeployType -eq "Standard"){


    Write-Host "Checking whether VM template file for $spoke ($VMsParametersFile) exists"
    if(Test-Path $VMsParametersFile){

    #Deploy the hub or spoke
    Write-Host "VM parameters file for $spoke exists. Spoke will be deployed"

    $services = (Get-Content $VMsParametersFile | convertfrom-json).parameters.services.value

    ForEach($service in $services){

        $serviceidentifier = $service.Identifier
        $subnetName = "sn-" + $service.subnetName
        $OS = $service.OS
        $LoadBalance = $service.LoadBalance
        $LBType = $service.LBType
        $VNName = "vn-pr-" + $Identifier + "-inf"
        $VNRGName = "rg-pr-" + $Identifier + "inf"
        $Encrypt = $service.Encrypt
        $Antimalware = $service.Antimalware
        $monitor = $service.Monitor

        if($OS -eq "WS2019")
        {
            $publisher = "MicrosoftWindowsServer"
            $offer = "WindowsServer"
            $sku = "2019-Datacenter"
            $version = "latest"
        }

        #Create resource group for all resources per  service
        $serviceRGName = "rg-pr-" + $Identifier + "-" + $serviceidentifier
        
        Write-Host "Creating resourcegroup $serviceRGName in $LocationPrimary"
        
        New-AzResourceGroup -Name $serviceRGName -Location $LocationPrimary -Force

        #Load balancer
        
        if($loadbalance -eq $true){
            Write-Host "Load balancer is $loadbalance. Creating internal load balancer in $serviceRGName"
            
            $LBFrontEndName = "$serviceidentifier" + "FrontEnd01"
            $LBFBackEndName = "$serviceidentifier" + "BackEnd01"

            if($LBType -eq "HTTPS"){
                $LBProbeName = "HP-HTTPS"
                $LBProbeProtocol = "HTTPS"
                $LBProbePort = "443"
            }

            $vnet = Get-AzVirtualNetwork -Name $VNName -ResourceGroupName $VNRGName
            $subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet

            $frontendIP = New-AzLoadBalancerFrontendIpConfig -Name $LBFrontEndName -SubnetId $subnet.Id

            $beaddresspool= New-AzLoadBalancerBackendAddressPoolConfig -Name $LBFBackEndName
            
            $healthProbe = New-AzLoadBalancerProbeConfig -Name $LBProbeName -Protocol $LBProbeProtocol -Port $LBProbePort -IntervalInSeconds 5 -ProbeCount 3 -RequestPath /
            
            if($LBType -eq "HTTPS"){
                $loadbrules = New-AzLoadBalancerRuleConfig -Name "LBR-HTTPS" -FrontendIpConfiguration $frontendIP -BackendAddressPool $beAddressPool -Probe $healthProbe -Protocol Tcp -FrontendPort $portNumber -BackendPort "443"
            }
            
            New-AzLoadBalancer -ResourceGroupName $serviceRGName -Name $LoadBalancerName -Location $location -FrontendIpConfiguration $frontendIP -LoadBalancingRule $loadbrules -BackendAddressPool $beAddressPool -Probe $healthProbe -SKU Standard -Force
        }
        $serviceAVSetName = "avs-pr-" + $Identifier + "-" + $serviceIdentifier
        $serviceAppSecGroupName = "asg-pr-" + $Identifier + "-" + $serviceIdentifier
        $VNName = "vn-pr-" + $Identifier
        $VNRGName = "rg-pr-" + $Identifier + "-inf"

        #Create virtual machine(s) for service
        New-AzResourceGroupDeployment -ResourceGroupName $serviceRGName `
                                      -TemplateParameterFile $VMsParametersFile `
                                      -TemplateFile $VMTemplateFile `
                                      -serviceidentifier $serviceidentifier `
                                      -AppSecGroupName $serviceAppSecGroupName `
                                      -AVSetName $serviceAVSetName `
                                      -NameforVnet $VNName `
                                      -NameforVnetRG $VNRGName `
                                      -DefaultUsername $DefaultUsername `
                                      -VMSize $DefaultVMSize `
                                      -publisher $publisher `
                                      -offer $offer `
                                      -sku $sku `
                                      -version $version `
                                      -subnetName $subnetName `
                                      -NameforKeyVault $NameforKeyVault `
                                      -RGNameforKeyVault `

        
        #VM spe<cific changes 
        $vmlist = (Get-Content $VMsParametersFile | convertfrom-json).parameters.vmstodeploy.value | Where-Object{$_.serviceIdentifier -eq $serviceidentifier}
        
        
        Write-Host "Cycling through VMs for other changes..."

        ForEach($VM in $vmlist){
            $vmname = $vm.VMName
            $PublicIP = $vm.publicIP

            Write-Host "Vm name $vmname in resource group $servicergname, for service $serviceidentifier"

            #Loop through required disks
            $disklist = (Get-Content $VMsParametersFile | convertfrom-json).parameters.DataDiskstoDeploy.value | Where-Object{$_.serviceIdentifier -eq $serviceidentifier -and $_.VMName -eq $VMName}

            $datadisknum = 0
            $lun = -1
            
            $vm = Get-AzVM -Name $vmname -ResourceGroupName $serviceRGName 

            ForEach($disk in $disklist){
                $datadisknum += 1
                $lun += 1
                $location = $location
                $DiskSizeGB = $disk.diskSizeGB
                $dataDiskName = $vmName + '-datadisk' + $datadisknum

                Write-Host "Creating disk $datadiskname"
                Write-Host "Disk size in GB - $disksizeGB"
                $diskConfig = New-AzDiskConfig -SkuName "Standard_LRS" -Location $LocationPrimary -CreateOption Empty -DiskSizeGB $DiskSizeGB -Zone $VMAvailZone
                $dataDisk = New-AzDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $serviceRGName

                $vm = Add-AzVMDataDisk -VM $vm -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk.Id -Lun $lun

            }
            
            Update-AzVM -VM $vm -ResourceGroupName $serviceRGName
       
            #Public IP addresses
            if($publicIP -eq $true){
                Write-Host "Deploying public ip for $vmname"
                $nicname = $vmname + "-nic"
                $pipname = $vmname + "-pip"
                
                $vnet = Get-AzVirtualNetwork -Name $VNName -ResourceGroupName $VNRGName
                #$subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet
                $nic = Get-AzNetworkInterface -Name $nicname -ResourceGroupName $serviceRGName
                $pip = New-AzPublicIpAddress -Name $pipname -ResourceGroupName $serviceRGName -AllocationMethod Static -Location $LocationPrimary -Sku Standard -Force
                $nic | Set-AzNetworkInterfaceIpConfig -Name ipconfig1 -PublicIPAddress $pip
                $nic | Set-AzNetworkInterface
            }
            else{
                "Public ip will not deploy as it is set to $publicip"
            }
        
            
            if($loadbalance -eq "true"){
                Write-Host "Load balance is $loadbalance. Adding vm to load balancer backend pool"
                $nicname = $vmname + "-nic01"            
                $nic = Get-AzNetworkInterface -Name $nicname -ResourceGroupName $serviceRGName
                
                $lb = Get-AzLoadBalancer -Name $LoadBalancerName -ResourceGroupName $serviceRGName

                $backend = Get-AzLoadBalancerBackendAddressPoolConfig -name $LBFBackEndName -LoadBalancer $lb
    
                $nic.IpConfigurations[0].LoadBalancerBackendAddressPools=$backend
                Set-AzNetworkInterface -NetworkInterface $nic
            
            }
            
            "++++++++++++++++++++++++++++++++ Encrypt is $encrypt"
            if($Encrypt -eq $true){

                Write-Host "Encrypting disks on $vmname"
                $keyVault = Get-AzKeyVault -VaultName $NameforKeyVault -ResourceGroupName $RGNameforKeyVault
                $diskEncryptionKeyVaultUrl = $keyVault.VaultUri
                $keyVaultResourceId = $keyVault.ResourceId
                $keyEncryptionKeyUrl = (Get-AzKeyVaultKey -VaultName $NameforKeyVault -Name $NameEncryptKey).Key.kid

                Set-AzVMDiskEncryptionExtension -ResourceGroupName $serviceRGName `
                    -VMName $vmname `
                    -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl `
                    -DiskEncryptionKeyVaultId $keyVaultResourceId `
                    -KeyEncryptionKeyUrl $keyEncryptionKeyUrl `
                    -KeyEncryptionKeyVaultId $keyVaultResourceId ` `
                    -Force
            }
            
            if($Antimalware -eq $true){
                "Deploying Microsoft antimalware"
                New-AzResourceGroupDeployment -ResourceGroupName $serviceRGName -TemplateFile $AntimalwareTemplatefile -ServiceIdentifier $serviceidentifier -TemplateParameterFile $VMsParametersFile
            }
            


            <#
            if($Backup -eq $true){

                New-AzResourceGroupDeployment -ResourceGroupName $RGNameforRSV -TemplateFile $BackupTemplatefile -Location $location -VMNameforBackup $VMName -VMRGName $serviceRGName -RSVRGName $RGNameforRSV -RSVName $NameforRSV -BackupPolicyName $backupPolicy
            }
            #>

            #Log Analytics agent

            if($Monitor -eq $true){
                "Deploying Log analytics agent"

                $workspaceRG = "rg-pr-core-mon" 
                
                $workspace = get-azresource | Where-Object{$_.ResourceGroupName -eq $workspaceRG -and $_.ResourceType -eq "Microsoft.OperationalInsights/workspaces"}

                $workspaceName = $workspace.Name

                $workspace = (Get-AzOperationalInsightsWorkspace).Where({$_.Name -eq $workspaceName})

                $workspaceId = $workspace.CustomerId

                New-AzResourceGroupDeployment -ResourceGroupName $serviceRGName -TemplateFile $LogAnalyticsTemplatefile -ServiceIdentifier $serviceidentifier -TemplateParameterFile $VMsParametersFile -workspaceName $workspaceName -WorkspaceId $workspaceId -workspaceRG $workspaceRG
            }
            
            #Automation DSC extensions
            $AutomationAccName = "aa-pr-core-aut-01" 
        
            New-AzResourceGroupDeployment -AutomationRG $AutomationRG -AutomationAccName $AutomationAccName -ResourceGroupName $serviceRGName -TemplateParameterFile $VMsParametersFile -TemplateFile $DSCTemplateFile -ServiceIdentifier $serviceidentifier

     
        }
    }  
}else{
    Write-Host "No VM parameters file for $spoke exists. No VMs will be deployed"
    exit
}







    }else{
        Write-Host "Deploy type of $DeployType is not valid. Value must be equal to 'firewall' or 'standard'."
        Write-Host "--------------------------------"
        Write-Host "End"
        Write-Host "--------------------------------"
        exit
    }