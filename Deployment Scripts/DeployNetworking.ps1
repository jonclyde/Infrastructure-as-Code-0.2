Param(
        [Parameter(Mandatory=$true)]
        $Spoke,
        [Parameter(Mandatory=$true)]
        $Identifier,
        [Parameter(Mandatory=$true)]
        $IdentifierforHub,
        [Parameter(Mandatory=$true)]
        $DeployDR,
        [Parameter(Mandatory=$true)]
        $LocationPrimary,
        [Parameter(Mandatory=$true)]
        $LocationDR,
        [Parameter(Mandatory=$true)]
        $DNSPrimary,
        [Parameter(Mandatory=$true)]
        $DNSSecondary
    )

    Write-Host "--------------------------------"
    Write-Host "Section 0 - Pre-requisites and set variables"
    Write-Host "--------------------------------"

    Write-Host "Set template and parameters paths"
    $NetTemplateFilePrimary = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\nested templates\virtual network\VirtualNetworkPrimary.json"))
    $NetTemplateFileDR = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\nested templates\virtual network\VirtualNetworkDR.json"))
    $NetPeerTemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\Nested Templates\Virtual Network Peering\vnetpeering.json"))
    $SpokeParamFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\parameters\$spoke.parameters.json"))

    Write-Host "Checking whether template file for $spoke exists"

    if(Test-Path $SpokeParamFile){
        Write-Host "Parameters file for $spoke exists. Spoke will be deployed"
        
        Write-Host "--------------------------------"
        Write-Host "Section 1 - Deploy networking"
        Write-Host "--------------------------------"

        #Deploy the hub or spoke
        $RGNamePrimary = "rg-pr-" + $Identifier + "-inf"
        $RGNameDR = "rg-dr-" + $Identifier + "-inf"
        $VNNamePrimary = "vn-pr-" + $Identifier
        $VNNameDR = "vn-dr-" + $Identifier 
        
        New-AzResourceGroup -Name $RGNamePrimary -Location $LocationPrimary -Force

        "Deploying PR $NetTemplateFilePrimary"
        New-AzResourceGroupDeployment -TemplateParameterFile $SpokeParamFile `
                                      -TemplateFile $NetTemplateFilePrimary `
                                      -ResourceGroupName $RGNamePrimary `
                                      -Identifier $Identifier `
                                      -VNName $VNNamePrimary `
                                      -EnvironmentIdentifier "pr"

        if($DeployDR -eq $true){
            New-AzResourceGroup -Name $RGNameDR -Location $LocationDR -Force
            "Deploying DR $NetTemplateFilePrimary"
            New-AzResourceGroupDeployment -TemplateParameterFile $SpokeParamFile `
                                      -TemplateFile $NetTemplateFileDR `
                                      -ResourceGroupName $RGNameDR `
                                      -Identifier $Identifier `
                                      -VNName $VNNameDR `
                                      -EnvironmentIdentifier "dr" `
                                      -DNSPrimary $DNSPrimary `
                                      -DNSSecondary $DNSSecondary
        }
        
        #Deploy VNET peering (for spokes only)
        if($spoke -eq "hub"){

            Write-Host "Deploy vnet peering between $VNNamePrimary and $VNNameDR"
            
            New-AzResourceGroupDeployment -TemplateFile $NetPeerTemplateFile -ResourceGroupName $RGNamePrimary -VN1Name $VNNamePrimary -VN2Name $VNNameDR -VN2RG $RGNameDR
        }
        else{

            $VNNameHubPrimary = "vn-pr-" + $IdentifierforHub
            $RGNameHubPrimary = "rg-pr-" + $IdentifierforHub + "-inf"

            Write-Host "Deploy vnet peering between $VNNamePrimary and $VNNameHubPrimary"

            New-AzResourceGroupDeployment -TemplateFile $NetPeerTemplateFile -ResourceGroupName $RGNameHubPrimary -VN1Name $VNNameHubPrimary -VN2Name $VNNamePrimary -VN2RG $RGNamePrimary
        
            $VNNameHubDR = "vn-dr-" + $IdentifierforHub
            $RGNameHubDR = "rg-dr-" + $IdentifierforHub + "-inf"

            Write-Host "Deploy vnet peering between $VNNamePrimary and $VNNameHubPrimary"

            New-AzResourceGroupDeployment -TemplateFile $NetPeerTemplateFile -ResourceGroupName $RGNameHubDR -VN1Name $VNNameHubDR -VN2Name $VNNameDR -VN2RG $RGNameDR
        
        }

    }else{
        Write-Host "No parameters file for $spoke exists. Spoke will not be deployed"
        Write-Host "--------------------------------"
        Write-Host "End"
        Write-Host "--------------------------------"
        
        exit
    }
