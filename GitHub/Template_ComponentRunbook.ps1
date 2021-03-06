﻿
<#
.DESCRIPTION
    A brief description on what is going on in the runbook

    Component / Script runbooks
    •	Modular, reusable – single purpose runbooks. (Tag: Component)
    •	Non modular, made for a specific purpose (Tag: Script)
    •	Uses Core runbooks to connect to resources
    •	Can be initiated from all higher tier runbooks (Interfaces, Controllers)
    •	Connects to azure resource manger if needed

.INPUTS
    NA

.OUTPUTS
    [Object]

.NOTES
    Version:        1.0.0
    Author:			
    Creation Date:	
    Purpose/Change:	Initial runbook development
#>

Param(

    <# Adjust Parmameters to what is needed
    [Parameter(Mandatory=$true)]
    [String]$Name,

    [Parameter(Mandatory=$true)]
    [String]$SamAccountName,

    [Parameter(Mandatory=$true)]
    [String]$Location,

    [Parameter(Mandatory=$true)]
    [String]$Path,

    [Parameter(Mandatory=$true)]
    [String]$DomainController#>

)

$ErrorActionPreference = "Stop"

<# To enable verbose stream set `$VerbosePreference to Continue, Verbose should also be 
   switched "On" on the runbook in Azure portal. Use Write-Verbose 
   in the runbook to write to verbose stream#>
$VerbosePreference = "SilentlyContinue"

# Provide the runbook with the same name as in Azure, this variable is used mainly for tracking
$RunbookName = ""

try
{
    #region Initialize Log
    $repo = Get-AutomationVariable -Name Repository
    . $repo\Classes\Log.ps1

    # Initialize Log
    [Array]$instance = [RunbookLog]::New()

    # Clone Logging Array to ArrayList to utalize array methods
    [System.Collections.ArrayList]$Log = $instance.Clone()

    # Clear Cloned array
    $Log.clear()
    #endregion

    # Initialize trace output stream, if the runbook is run in Azure the computername will return CLIENT
    $Log.Add($instance.WriteLogEntry($RunbookName,"Running on ($env:COMPUTERNAME)")) | Out-Null

    # Optional - Connect to Azure Resource Manager, ignore if this is called from an Control runbook 
    # Where connection already has been initialized with the variable `$conn
    try{
        Get-AzureRmAutomationAccount | Out-Null
    }
    catch{
        $conn = .\Connect-AzureRMAutomation.ps1
        
        # Recieve log from sub runbook
        foreach ($i in $conn.Trace){
            $Log.Add($instance.WriteLogEntry($i.RunbookName,$i.Message)) | Out-Null
        }

        if($conn.status -ne "Success"){
            Throw "Error - Connecting to Azure failed"
        } 
    }
           
    # Import Modules and setup implicit remoting, use component runbooks to setup implicit remoting
    $modules = @()
    $modules += .\Connect-MSOnline.ps1
    $modules += .\Connect-ExchangeOnline.ps1

    # Recieve log from sub runbook
    foreach ($i in $modules.trace){
        $Log.Add($instance.WriteLogEntry($i.RunbookName,$i.Message)) | Out-Null
    }

    # Make sure that the modules were imported for the runspace
    if($modules[0].ObjectCount -lt 1 -or $modules[1].ObjectCount -lt 1){
        Throw "Error - One or more modules was not imported"
    }

    <#
        CODE GOES HERE
    #>
       
    # Return values used for further processing, add properties if needed
    $props = [Ordered]@{'Status' = "Success"
                        'Message' = "Runbook Finished Successfully"
                        'ObjectCount' = 1
    }
}

catch
{
    # Add to trace on what line the error occured and the exception message
    $excep = $(if($_.Exception.Message.Contains("`"")){$_.Exception.Message.Replace("`"","'")}else{$_.Exception.Message})
    $Log.Add($instance.WriteLogEntry($RunbookName,"Exception Caught at line $($_.InvocationInfo.ScriptLineNumber), $excep")) | Out-Null

    # Return values used for further processing, add properties if needed
    $props = [Ordered]@{'Status' = $status
                        'Message' = $excep
                        'ObjectCount' = 0
    }

    Write-Error $excep -ErrorAction Continue
}
finally
{
    # Remove session if needed, change if needed
    try{
        Remove-PSSession -name $($modules[1].Connect.Session.Name)
        $Log.Add($Instance.WriteLogEntry($RunbookName,"Removing session $($modules[1].Connect.Session.Name)")) | Out-Null
    }
    catch{
        $Log.Add($Instance.WriteLogEntry($RunbookName,"Session does not exist $($modules[1].Connect.Session.Name)")) | Out-Null
    }

    $props.Add('Trace',$trace)
    $props.Add('RunbookName',$RunbookName)

    $out = New-Object -TypeName PSObject -Property $props

    # optional, use Send-Email to send email or sms notifications, for sms use EmailAddressTo file with +45xxxxxxxx@sms.ecco.local
    # Body parameter has to be an object
    $email = .\Send-Email.ps1 -EmailAddressTO $(Get-AutomationVariable -Name "Email-PJE") -Subject "Daily Report $RunbookName" -Body $Out -AsHtml

    Write-Output $out
}  