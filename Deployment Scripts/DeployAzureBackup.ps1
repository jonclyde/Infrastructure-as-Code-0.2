Param(
        [Parameter(Mandatory=$true)]
        $identifier,
        [Parameter(Mandatory=$true)]
        $EnvironmentIdentifier,
        [Parameter(Mandatory=$true)]
        $DeployDR,
        [Parameter(Mandatory=$true)]
        $LocationPrimary,
        [Parameter(Mandatory=$true)]
        $LocationDR
    )

    Write-Host "--------------------------------"
    Write-Host "Section 0 - Pre-requisites and set variables"
    Write-Host "--------------------------------"

    Write-Host "Set template and parameters paths"
    $RSVTemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\nested templates\Azure Backup\vault.json"))
    $RandomInteger = Get-Random

    Write-Host "--------------------------------"
    Write-Host "Section 1 - Deploy Azure Backup"
    Write-Host "--------------------------------" 

    $RGNamePrimary = "rg-pr-" + $identifier + "-rec"
    $RSVBUNamePrimary = "rsv-pr-" + $identifier + "-bu-" + $RandomInteger 
    
    $RGNameDR = "rg-dr-" + $identifier + "-rec"
    $RSVBUNameDR = "rsv-dr-" + $identifier + "-bu-" + $RandomInteger 
    $RSVASRNameDR = "rsv-dr-" + $identifier + "-asr-" + $RandomInteger 

    New-AzResourceGroup -Name $RGNamePrimary -Location $LocationPrimary -Force
    New-AzResourceGroup -Name $RGNameDR -Location $LocationDR -Force

    Write-Host "Deploying vault for backup in the primary region"
    New-AzResourceGroupDeployment -TemplateFile $RSVTemplateFile -ResourceGroupName $RGNamePrimary -RSVName $RSVBUNamePrimary

    if($DeployDR -eq "true")
    {
        Write-Host "Deploying vault for backup in the DR region"
        New-AzResourceGroupDeployment -TemplateFile $RSVTemplateFile -ResourceGroupName $RGNameDR -RSVName $RSVBUNameDR
        
        Write-Host "Deploying vault for Azure Site Recovery in the DR region"
        New-AzResourceGroupDeployment -TemplateFile $RSVTemplateFile -ResourceGroupName $RGNameDR -RSVName $RSVASRNameDR
    }