Login-AzAccount

Select-azsubscription "847f0a11-c32e-4c42-8d99-ae7bb0dd6b59"

.\DeployNetworking.ps1 -Spoke "Hub" -Identifier "core" -DeployDR "true" -LocationPrimary "westeurope" -LocationDR "northeurope" -IdentifierforHub "core"

.\DeployNetworking.ps1 -Spoke "spoke1" -Identifier "app1" -DeployDR "true" -LocationPrimary "westeurope" -LocationDR "northeurope" -IdentifierforHub "core"

.\DeployNetworking.ps1 -Spoke "spoke2" -Identifier "rds" -DeployDR "true" -LocationPrimary "westeurope" -LocationDR "northeurope" -IdentifierforHub "core"

New-AzResourceGroupDeployment -TemplateFile ".\Storage Account\storageaccount.json" -TemplateParameterFile "..\Parameters\StorageAccounts.parameters.json" -ResourceGroupName "az-core-recovery"

New-AzResourceGroupDeployment -TemplateFile ".\Log Analytics\workspace.json" -ResourceGroupName "az-core-recovery" -identifier "core" -RandomInteger "43278423"

New-AzResourceGroupDeployment -TemplateFile ".\Azure Backup\vault.json" -ResourceGroupName "az-core-recovery" -identifier "core" -RandomInteger "43278423" -DeployDR "true" -LocationPrimary "westeurope" -LocationDR "northeurope"

.\DeployAzureBackup.ps1 -identifier "core" -DeployDR "true" -LocationPrimary "westeurope" -LocationDR "northeurope"

cd "C:\Users\jon\repos\Infrastructure-as-Code-0.2\Deployment Scripts"

.\DeployVMs.ps1 -Spoke "hub" `
                -Identifier "core" `
                -DeployType "standard" `
                -NameforKeyVault "kv-pr-core" `
                -RGNameforKeyVault "rg-pr-core-key" `
                -DeployFW "true" `
                -DeployDR "true" `
                -FirewallHubSubnetName "sn-Firewall" `
                -FirewallHubSubnetRangePrimary "FirewallHubSubnetRangePrimary" `
                -FirewallHubSubnetRangeDR "FirewallHubSubnetRangeDR" `
                -DefaultVMSize "Standard_B2S" `
                -LocationPrimary "westeurope" `
                -LocationDR "northeurope" `
                -DefaultUsername "ladmin" `
                -AutomationRG "rg-pr-core-aut" `
                -NameEncryptKey "encKey"    

.\DeployRouting.ps1 -Spoke "hub" -Identifier "core" -DeployFirewalls "true" -FirewallHubSubnetName "sn-Firewall" -LocationPrimary "westeurope" -LocationDR "northeurope"


    


                Param(
                    [Parameter(Mandatory=$true)]
                    $Spoke,
                    [Parameter(Mandatory=$true)]
                    $Identifier,
                    [Parameter(Mandatory=$true)]
                    $Location,
                    [Parameter(Mandatory=$true)]
                    $DeployFirewalls,
                    [Parameter(Mandatory=$false)]
                    $FirewallIP,
                    [Parameter(Mandatory=$false)]
                    $FirewallHubSubnetName
                )