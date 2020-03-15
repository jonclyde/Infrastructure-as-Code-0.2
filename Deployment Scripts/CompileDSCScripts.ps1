Param(
        [Parameter(Mandatory=$true)]
        $AutomationAccName,
        [Parameter(Mandatory=$true)]
        $AutomationRGName
    )

    Write-Host "--------------------------------"
    Write-Host "Section 0 - Pre-requisites and set variables"
    Write-Host "--------------------------------"

    Write-Host "Set template and parameters paths"
    $AutomationParamFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\parameters\automation.parameters.json"))

    Write-Host "Getting DSC configurations from $AutomationParamFile"
    $dscConfigurations = (Get-Content $AutomationParamFile  | convertfrom-json).parameters.dscConfigurations.value

    Write-Host "About to loop through configurations and start compilation jobs"

    ForEach($config in $dscConfigurations)
    {
        $ConfigName = $config.ConfigName
        $ConfigurationDataFileName = $config.ConfigurationDataFileName
        
        Write-host "Working on configuration $configname"

        $AutConfig = Get-AzAutomationDscConfiguration -ResourceGroupName AutomationRGName -AutomationAccountName $AutomationAccName | Where-Object{$_.Name -eq $ConfigName}
        
        if($ConfigurationDataFileName)
        {
            Write-Host "$configname has configuration data file; $configurationdatafilename"

            $ConfigurationDataFilePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..\parameters\$ConfigurationDataFileName"))

            $ConfigData = Import-PowerShellDataFile $ConfigurationDataFilePath
            
            $autconfig | Start-AzAutomationDscCompilationJob -ConfigurationData $ConfigData
        }
        else{
            $autconfig | Start-AzAutomationDscCompilationJob
        }
    }



