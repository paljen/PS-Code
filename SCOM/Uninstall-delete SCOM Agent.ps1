
Import-module OperationsManager

$ErrorActionPreference = "Stop"

$server = "dkhqexcman02.prd.eccocorp.net"
$SCOM_MGMT = "eccomon.prd.eccocorp.net"

New-SCOMManagementGroupConnection -ComputerName $SCOM_MGMT | Out-Null

$adm = (Get-SCOMManagementGroup).GetAdministration()

try 
{

    $agent = Get-SCOMAgent $cn

    if(Test-Connection $cn -Count 1 -ErrorAction SilentlyContinue)
    {
        write-host "The server is turned on - the agent will be uninstalled"
        #Uninstall-SCOMAgent -Agent $agent
    }
    else
    {
        $list = [System.Collections.Generic.List``1].MakeGenericType([Microsoft.EnterpriseManagement.Administration.AgentManagedComputer])
        $obj = New-Object $list.FullName
        $agent = Get-SCOMAgent dkhqexcman02.prd.eccocorp.net
        $obj.Add($agent)

        Write-host "The server is not online and the scom object will be deleted`n$obj"

        $adm.DeleteAgentManagedComputers($obj)
    }
}
catch
{
    $_.exception.message
}