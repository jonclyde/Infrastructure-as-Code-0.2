@{

    AllNodes = @(
        @{
            NodeName        = "FirstDomainController"
            Elements        = "FirstDC"
        },

        @{
            NodeName        = "OtherDomainController"
            Elements        = "OtherDC"
        },

        @{
            NodeName        = "SQLVM"
            Elements        = "MSSQL","DomainJoin"
        },

        @{
            NodeName        = "WindowsManagementVM"
            Elements        = "Management", "DomainJoin"
        },

        @{
            NodeName        = "WebServer"
            Elements        = "IIS", "DomainJoin"
        }
    )
}