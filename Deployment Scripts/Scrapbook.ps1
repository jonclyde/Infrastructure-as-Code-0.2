cd "C:\Users\jon.clyde\Documents\GitHub\Infrastructure-as-Code-0.2\Deployment Scripts"

Login-AzAccount

Select-azsubscription "847f0a11-c32e-4c42-8d99-ae7bb0dd6b59"

.\DeployNetworking.ps1 -Spoke "Hub" -Identifier "core" -DeployDR "true" -LocationPrimary "westeurope" -LocationDR "northeurope" -IdentifierforHub "core"

.\DeployNetworking.ps1 -Spoke "spoke1" -Identifier "app1" -DeployDR "true" -LocationPrimary "westeurope" -LocationDR "northeurope" -IdentifierforHub "core"

.\DeployNetworking.ps1 -Spoke "spoke2" -Identifier "rds" -DeployDR "true" -LocationPrimary "westeurope" -LocationDR "northeurope" -IdentifierforHub "core"

New-AzResourceGroupDeployment -TemplateFile ".\Storage Account\storageaccount.json" -TemplateParameterFile "..\Parameters\StorageAccounts.parameters.json" -ResourceGroupName "az-core-recovery"

New-AzResourceGroupDeployment -TemplateFile ".\Log Analytics\workspace.json" -ResourceGroupName "az-core-recovery" -identifier "core" -RandomInteger "43278423"

New-AzResourceGroupDeployment -TemplateFile ".\Azure Backup\vault.json" -ResourceGroupName "az-core-recovery" -identifier "core" -RandomInteger "43278423" -DeployDR "true" -LocationPrimary "westeurope" -LocationDR "northeurope"

.\DeployAzureBackup.ps1 -identifier "core" -DeployDR "true" -LocationPrimary "westeurope" -LocationDR "northeurope"