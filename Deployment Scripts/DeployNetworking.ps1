Param(
        [Parameter(Mandatory=$true)]
        $Spoke,
        [Parameter(Mandatory=$true)]
        $Identifier,
        [Parameter(Mandatory=$true)]
        $DeployDR,
        [Parameter(Mandatory=$true)]
        $LocationPrimary,
        [Parameter(Mandatory=$true)]
        $LocationDR
    )

    Write-Host "--------------------------------"
    Write-Host "Section 0 - Set variables"
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
        $RGNamePrimary = "rg-pr-" + $Identifier
        $RGNameDR = "rg-dr-" + $Identifier 
        $VNNamePrimary = "vn-pr-" + $Identifier
        $VNNameDR = "vn-dr-" + $Identifier 
        
        New-AzResourceGroup -Name $RGNamePrimary -Location $LocationPrimary -Force

        New-AzResourceGroupDeployment -TemplateParameterFile $SpokeParamFile `
                                      -TemplateFile $NetTemplateFilePrimary `
                                      -ResourceGroupName $RGNamePrimary `
                                      -Identifier $Identifier `
                                      -VNName $VNNamePrimary `
                                      -EnvironmentIdentifier "pr"

        if($DeployDR -eq $true){
            New-AzResourceGroup -Name $RGNameDR -Location $LocationPrimary -Force

            New-AzResourceGroupDeployment -TemplateParameterFile $SpokeParamFile `
                                      -TemplateFile $NetTemplateFileDR `
                                      -ResourceGroupName $RGNameDR `
                                      -Identifier $Identifier `
                                      -VNName $VNNameDR `
                                      -EnvironmentIdentifier "dr"
        }
        
        #Deploy VNET peering (for spokes only)
        if($spoke -eq "hub"){

            Write-Host "Deploy vnet peering between $VNNamePrimary and $VNNameDR"

            New-AzResourceGroupDeployment -TemplateFile $NetPeerTemplateFile -ResourceGroupName $RGNamePrimary -VN1Name $VNNamePrimary -VN2Name $VNNameDR -VN2RG $RGNameDR
        }
        else{

            Write-Host "Deploy vnet peering between $identifier and $hubidentifier"

            New-AzResourceGroupDeployment -TemplateFile $VNetPeerTemplateFile -ResourceGroupName $RGName -spokeIdentifier $Identifier -HubIdentifier $HubIdentifier -HubRG $HubRG
        }

    }else{
        Write-Host "No parameters file for $spoke exists. Spoke will not be deployed"
        Write-Host "--------------------------------"
        Write-Host "End"
        Write-Host "--------------------------------"
        
        exit
    }
