
Import-module OperationsManager

$ErrorActionPreference = "Stop"

$server = "dkhqexcman02.prd.eccocorp.net"
$SCOM_MGMT = "eccomon.prd.eccocorp.net"

New-SCOMManagementGroupConnection -ComputerName $SCOM_MGMT | Out-Null

try 
{
    if($agent = Get-SCOMAgent $server)
    {
        $job = Uninstall-SCOMAgent -Agent $agent -PassThru
      
        if($job.ErrorCode -eq 0)
        {
            $status = "Success"
            $message = $job.Description
        }
        else
        {
            $status = "Failed"
            $message = $job.Description
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