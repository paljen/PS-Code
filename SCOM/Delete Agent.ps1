
Import-module OperationsManager

$ErrorActionPreference = "Stop"

$server = "dkhqexcman02.prd.eccocorp.net"
$SCOM_MGMT = "eccomon.prd.eccocorp.net"

New-SCOMManagementGroupConnection -ComputerName $SCOM_MGMT | Out-Null

$adm = (Get-SCOMManagementGroup).GetAdministration()

try 
{
    if($agent = Get-SCOMAgent $server)
    {
        $type = [System.Collections.Generic.List``1].MakeGenericType([Microsoft.EnterpriseManagement.Administration.AgentManagedComputer])
        $list = New-Object $type.FullName
        $list.Add($agent)
        $test = $adm.DeleteAgentManagedComputers($list)
        
        if((Get-SCOMAgent $server) -eq $null)
        {
            $status = "Success"
            $message = "Agent on remote computer $server successfully deleted"
        }
    }
    else
    {
        $status = "Failed"
        $message = "No agent on remote computer $server"
    }
}
catch
{
    $status = "Failed"
    $message = $_.exception.message
}