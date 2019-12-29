Param(
        [Parameter(Mandatory=$true)]
        $Spoke,
        [Parameter(Mandatory=$true)]
        $Identifier,
        [Parameter(Mandatory=$true)]
        $DeployType,
        [Parameter(Mandatory=$true)]
        $SubscriptionID,
        [Parameter(Mandatory=$true)]
        $NameforKeyVault,
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
        $LocationPrimary,
        [Parameter(Mandatory=$true)]
        $LocationDR
    )
    Write-Host "--------------------------------"
    Write-Host "Section 0 - Pre-requisites and set variables"
    Write-Host "--------------------------------"
    $BarracudaTemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\nested templates\virtual network\VirtualNetworkPrimary.json"))
    
    if($DeployType -eq "firewall" -and $spoke -ne "hub"){
        Write-Host "Parameters are invalid. Deploy type is firewall but spoke is not set to hub"
        Write-Host "Deploy type - $DeployType"
        Write-Host "Spoke - $spoke"
        Write-Host "--------------------------------"
        Write-Host "End"
        Write-Host "--------------------------------"
    }
    Write-Host "Checking value of the deploy type parameter"

    if($DeployType -eq "Firewall"){
        
        if($DeployFW -eq $true){
            Write-Host "DeployFW parameter is set to true. Primary firewalls will now be deployed"

            $FWRGNamePrimary = "rg-pr-" + $identifier + "-fw"
            $FWVNRGPrimary = "rg-pr-" + $identifier

            New-AzResourceGroup -Name $RGNamePrimary -Location $LocationPrimary -Force

            New-AzResourceGroupDeployment -TemplateFile $BarracudaTemplateFile `
                                          -ResourceGroupName $FWRGNamePrimary `
                                          -VNFirewallRG $FWVNRGPrimary
                                          -FirewallHubSubnetIdentifier $FirewallHubSubnetIdentifier `


            if($DeployDR -eq $true){

                $FWRGNameDR = "rg-dr-" + $identifier + "-fw"
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

    }else{
        Write-Host "Deploy type of $DeployType is not valid. Value must be equal to 'firewall' or 'standard'."
        Write-Host "--------------------------------"
        Write-Host "End"
        Write-Host "--------------------------------"
        exit
    }