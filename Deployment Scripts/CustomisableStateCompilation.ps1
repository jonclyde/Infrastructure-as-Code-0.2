Configuration CustomisableState {
    param(
        [parameter(Mandatory=$true)]
        [boolean] $FirstDC,
        [parameter(Mandatory=$true)]
        [boolean] $OtherDC,
        [parameter(Mandatory=$true)]
        [boolean] $MSSQLVM,
        [parameter(Mandatory=$true)]
        [Int] $MSSQLMinMem,
        [parameter(Mandatory=$true)]
        [Int] $MSSQLMaxMem,
        [parameter(Mandatory=$true)]
        [string] $ManagmentVM,
        [parameter(Mandatory=$true)]
        [string] $DoNotDomainJoin
    )

    Import-DscResource -ModuleName 'PsDesiredStateConfiguration'
    Import-DscResource -ModuleName 'ComputerManagementDsc'
    Import-DscResource -ModuleName 'xDSCDomainJoin'
    Import-DscResource -ModuleName 'xStorage'
    Import-DscResource -ModuleName 'SqlServerDsc'

    $DomainAdminCredential = Get-AutomationPSCredential -Name 'domainCredential'
    $DomainJoinCredential = Get-AutomationPSCredential -Name 'domainJoinCredential'
    $SafeModePassword = Get-AutomationPSCredential -Name 'safeModeCredential'
    $DomainName = Get-AutomationVariable -Name 'DomainName'
    

    # Configuration
    node localhost
    {
        <#
            First Domain controller configuration
        #>
        if($FirstDC -eq $true)
        {
            WindowsFeature ADDSInstall
            {
                Ensure = 'Present'
                Name = 'AD-Domain-Services'
            }
    
            WindowsFeature RSATTools 
            { 
                Ensure = 'Present'
                Name = 'RSAT-AD-Tools'
                IncludeAllSubFeature = $true
            }
    
            xWaitforDisk Disk3
            {
                DiskId = 3
                RetryIntervalSec = 10
                RetryCount = 30
            }
     
            xDisk DiskF
            {
                DiskId = 3
                DriveLetter = 'F'
                DependsOn = '[xWaitforDisk]Disk3'
                FSLabel = 'Domain'
            }
            PendingReboot RebootBeforeDC
            {
                Name = 'RebootBeforeDC'
                SkipCcmClientSDK = $true
                DependsOn = '[WindowsFeature]ADDSInstall','[xDisk]DiskF'
            }
            
            xADDomain Domain
            {
                DomainName = $DomainName
                DomainAdministratorCredential = $DomainAdminCredential
                SafemodeAdministratorPassword = $SafeModePassword
                DatabasePath = 'F:\NTDS'
                LogPath = 'F:\NTDS'
                SysvolPath = 'F:\SYSVOL'
                DependsOn = '[WindowsFeature]ADDSInstall','[xDisk]DiskF','[PendingReboot]RebootBeforeDC'
            }
     
            Registry DisableRDPNLA
            {
                Key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
                ValueName = 'UserAuthentication'
                ValueData = 0
                ValueType = 'Dword'
                Ensure = 'Present'
                DependsOn = '[xADDomain]Domain'
            }

        }
        <#
            Other Domain controller configuration
        #>
        if($OtherDC -eq $true)
        {
            WindowsFeature ADDSInstall
            {
                Ensure = 'Present'
                Name = 'AD-Domain-Services'
            }
            
            WindowsFeature RSATTools 
            { 
                Ensure = 'Present'
                Name = 'RSAT-AD-Tools'
                IncludeAllSubFeature = $true
            }

            xWaitforDisk Disk3
            {
                DiskId = 3
                RetryIntervalSec = 10
                RetryCount = 30
            }
    
            xDisk DiskF
            {
                DiskId = 3
                DriveLetter = 'F'
                DependsOn = '[xWaitforDisk]Disk3'
                FSLabel = 'Domain'
            }
            xDSCDomainjoin JoinDomain
            {
                Domain = $DomainName 
                Credential = $domainJoinCredential
            }
            <#PendingReboot AfterDomainJoin
            {
                Name = 'AfterDomainJoin'
                SkipCcmClientSDK = $true
                DependsOn = '[WindowsFeature]ADDSInstall','[xDisk]DiskF','[Computer]JoinDomain'
            }#>
            xWaitForADDomain 'DscForestWait'
            {
                DomainName           = $DomainName
                DomainUserCredential = $domainJoinCredential
                RetryCount           = 10
                RetryIntervalSec     = 30
                DependsOn            = '[WindowsFeature]ADDSInstall'
            }
    
            xADDomain Domain
            {
                DomainName = $DomainName
                DomainAdministratorCredential = $DomainCredential
                SafemodeAdministratorPassword = $SafeModePassword
                DatabasePath = 'F:\NTDS'
                LogPath = 'F:\NTDS'
                SysvolPath = 'F:\SYSVOL'
                DependsOn = '[WindowsFeature]ADDSInstall','[xDisk]DiskF','[xWaitForADDomain]DscForestWait'
                #'[PendingReboot]AfterDomainJoin'
            }
            
            Registry DisableRDPNLA
            {
                Key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
                ValueName = 'UserAuthentication'
                ValueData = 0
                ValueType = 'Dword'
                Ensure = 'Present'
                DependsOn = '[xADDomain]Domain'
            }
        }

        <#
            SQL Server configuration
        #>
        if($MSSQLVM -eq $true)
        {
            SqlServerMemory 'Set_SQLServerMaxMemory'
            {
                Ensure               = 'Present'
                DynamicAlloc         = $false
                MinMemory            = $minmem
                MaxMemory            = $maxmem
                ServerName           = 'localhost'
                InstanceName         = 'MSSQLSERVER'
            }
                
            xDSCDomainjoin JoinDomain
            {
                Domain = $DomainName
                Credential = $domainJoinCredential
            }
        }
        <#
            Management VM configuration
        #>

        if($ManagementVM -eq $true){
            WindowsFeature RSATTools 
            { 
                Ensure = 'Present'
                Name = 'RSAT-AD-Tools'
                IncludeAllSubFeature = $true
            }
        
            xDSCDomainjoin JoinDomain
            {
                Domain = $DomainName 
                Credential = $domainJoinCredential 
            }
        }
        
    }
}