<#
.SYNOPSIS
	Force an Azure AD Syncronization

.PARAMETER  ComputerName
    Remote server on where to run the syncronization

.PARAMETER  SyncType
    What type of syncronization needs to be preformed, Delta or Initial

.NOTES
    Parameters are passed from Orchestrator in form of an hashtable

.NOTES
    Version:        1.0.0
    Author:			Admin-PJE
    Creation Date:	21/02/2017
    Purpose/Change:	Initial runbook development
#>

param(
    [Parameter(Mandatory=$true)]
    [String]$ComputerName,

    [Parameter(Mandatory=$true)]
    [ValidateSet("Delta", "Initial")]
    [String]$SyncType
)

$ErrorActionPreference = "Stop"

<# To enable verbose stream set `$VerbosePreference to Continue, Verbose should also be 
   switched "On" on the runbook in Azure portal. Use Write-Verbose 
   in the runbook to write to verbose stream#>
$VerbosePreference = "SilentlyContinue"

# Provide the runbook with the same name as in Azure, this variable is used mainly for tracking
$RunbookName = "Invoke-AzureADSync"

try
{
    Function Add-TraceEntry($string)
    {
        "$([DateTime]::Now.ToString())`t$string`n"        
    }

    # Initialize trace output stream, if the runbook is run in Azure the computername will return CLIENT
    $trace = ""
    $trace += Add-TraceEntry "$RunbookName Running on ($env:COMPUTERNAME)"
   
    # Azure AD Syncronization
    $out = Invoke-Command -ComputerName $($ComputerName) -ScriptBlock {
        Import-Module ADSync

        # Initialize state to failed
        $state = "Failed"

        # Test if synctype is valid
        switch ($using:SyncType){
            "Delta" {$attemps = 3}
            "Initial" {$attemps = 1}
            Default {Throw "$($using:SyncType) not a valid synctype"}
        }
        
        try{
            if((Get-ADSyncConnectorRunStatus).runstate -isnot [Object]){               
                
                # Waiting for AD Connect to syncronize
                for ($i = 0; $i -lt $attemps; $i++){ 
                    Start-Sleep 5
                    Start-ADSyncSyncCycle -PolicyType $using:SyncType | Out-Null
                    $trace += "$([DateTime]::Now.ToString())`tSynccycle $using:SyncType started, Attempt: $($i+1)`n"
    
                    do{
                        Start-sleep 10
                    }
                    until ((Get-ADSyncConnectorRunStatus).runstate -isnot [Object])
                }

                # If all 3 attempts is success set state to success, the state will be warning if 1 sync fails
                $state = "Success"
                @{'Message'="Completed Successfully ";'State'=$state;'Trace'=$trace}
            }
            else{
                # State Warning will be rerun
                $state = "Warning"
                Throw "Connector: $((Get-ADSyncConnectorRunStatus).ConnectorName) is busy"
            }
        }
        catch{
            @{'Message'=$_.Exception.Message;'State'=$state;'Trace'=$trace}
        }
    }

    # Check the provioning status
    if($out.State -eq "Warning"){
        # Hack variable used to avoid failed status on throw, failed state will break runbook loop
        $syncStatus = $true
        Throw "$($out.Message)"}
    if($out.State -eq "Failed"){
        Throw $out.Message}

    $trace += $out.Trace
    $trace += Add-TraceEntry "Successfully finished Azure AD Syncronization"
    
    # Return values to component runbook
    $props = @{'Status' = "Success"
               'AADSync' = @{'Values'=$out}
               'Message' = "Runbook Finished Successfully"
               'ObjectCount' = 1}
}
catch
{
    # Add to trace on what line the error occured and the exception message
    $excep = $(if($_.Exception.Message.Contains("`"")){$_.Exception.Message.Replace("`"","'")}else{$_.Exception.Message})
    $trace += Add-TraceEntry "Exception Caught at line $($_.InvocationInfo.ScriptLineNumber), $excep"

    # If you throw the error 
    if($_.Exception.WasThrownFromThrowStatement)
    {$status = "failed"}
    else
    {$status = "warning"}

    # Return values to component runbook
    $props = @{'Status' = $status
               'AADSync' = @{'Values'=$out
               'Message' = $excep}
               'ObjectCount' = 0}
}
finally
{
    $props.Add('Trace',$trace)
    $props.Add('RunbookName',$RunbookName)

    $out = New-Object -TypeName PSObject -Property $props

    Write-Output $out
}
 