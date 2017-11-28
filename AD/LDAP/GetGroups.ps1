 # Initializing Directory Services
$rootDSE = [System.DirectoryServices.DirectoryEntry]("LDAP://RootDSE")
$RootPath = "LDAP://{0}" -f $rootDSE.defaultNamingContext.ToString()
$root = [System.DirectoryServices.DirectoryEntry]$RootPath

$machineName = $env:COMPUTERNAME
$objOU = [ADSI]”LDAP://dkhqdc01:389/OU=PATCH MANAGEMENT,OU=CENTRALLY MANAGED,OU=Groups,DC=prd,DC=eccocorp,DC=net“
$objOU.Children.name

<#
$GroupName = “GROUPNAME_” + $machineName
$objGroup = $objOU.Create(“group”, “CN=” + $GroupName)
$objGroup.Put(“sAMAccountName”, $GroupName )
$objGroup.SetInfo()#>

