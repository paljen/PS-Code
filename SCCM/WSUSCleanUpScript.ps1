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
    Author:			admin-pje
    Creation Date:	
    Purpose/Change:	Initial runbook development
#>

Param(

)

$ErrorActionPreference = "Stop"

<# To enable verbose stream set `$VerbosePreference to Continue, Verbose should also be 
   switched "On" on the runbook in Azure portal. Use Write-Verbose 
   in the runbook to write to verbose stream#>
$VerbosePreference = "SilentlyContinue"

# Provide the runbook with the same name as in Azure, this variable is used mainly for tracking
$RunbookName = "Start-WSUSCleanUpdateCleanup"

try
{
    Function Add-TraceEntry($string)
    {
        "$([DateTime]::Now.ToString())`t$string`n"        
    }

    # Initialize trace output stream, if the runbook is run in Azure the computername will return CLIENT
    $trace = ""
    $trace += Add-TraceEntry "$RunbookName Running on ($env:COMPUTERNAME)"

    # Optional - Connect to Azure Resource Manager, ignore if this is called from an Control runbook 
    # Where connection already has been initialized with the variable `$conn
    try{
        Get-AzureRmAutomationAccount | Out-Null
        $trace += Add-TraceEntry "Already Logged into Azure Resource Manager, $($conn.status)"
    }
    catch{
        $conn = .\Connect-AzureRMAutomation.ps1
        $trace += "$($conn.Trace)"

        if($conn.status -ne "Success")
        {
            Throw "Error - Connecting to Azure failed"
        } 
    }

    Write-verbose "Successfully Logged into Azure!"
            
    Add-Type -Path "C:\Program Files\Update Services\API\Microsoft.UpdateServices.Administration.dll"

    $UseSSL = $False

    $PortNumber = 8530

    $Server = "dkhqsccm02"

    $ReportLocation = "C:\TEMP\WSUS_CleanUpTaskReport.html"

    $To = "pje@ecco.com"

    $WSUSConnection = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($Server,$UseSSL,$PortNumber)

    #Clean Up Scope

    $CleanupScopeObject = New-Object Microsoft.UpdateServices.Administration.UpdateScope #CleanupScope
    $CleanupScopeObject.CleanupObsoleteComputers = $True
    $CleanupScopeObject.CleanupObsoleteUpdates = $True
    $CleanupScopeObject.CleanupUnneededContentFiles = $True
    $CleanupScopeObject.CompressUpdates = $True
    $CleanupScopeObject.DeclineExpiredUpdates = $True
    $CleanupScopeObject.DeclineSupersededUpdates = $True
    $CleanupTASK = $WSUSConnection.GetCleanupManager()
    $Results = $CleanupTASK.PerformCleanup($CleanupScopeObject)


    $DObject = New-Object PSObject
    $DObject | Add-Member -MemberType NoteProperty -Name "SupersededUpdatesDeclined" -Value $Results.SupersededUpdatesDeclined
    $DObject | Add-Member -MemberType NoteProperty -Name "ExpiredUpdatesDeclined" -Value $Results.ExpiredUpdatesDeclined
    $DObject | Add-Member -MemberType NoteProperty -Name "ObsoleteUpdatesDeleted" -Value $Results.ObsoleteUpdatesDeleted
    $DObject | Add-Member -MemberType NoteProperty -Name "UpdatesCompressed" -Value $Results.UpdatesCompressed
    $DObject | Add-Member -MemberType NoteProperty -Name "ObsoleteComputersDeleted" -Value $Results.ObsoleteComputersDeleted
    $DObject | Add-Member -MemberType NoteProperty -Name "DiskSpaceFreed" -Value $Results.DiskSpaceFreed

    #HTML style
    $HeadStyle = "<style>"
    $HeadStyle += "h1, h5, th { text-align: center;}"
    $HeadStyle += "table { margin: auto; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey;}"
    $HeadStyle += "th { background: #0046c3; color: #fff; max-width: 400px; padding: 5px 10px;}"
    $HeadStyle += "td { font-size: 11px; padding: 5px 20px; color: #000;}"
    $HeadStyle += "tr { background: #b8d1f3;}"
    $HeadStyle += "tr:nth-child(even) { background: #dae5f4;}"
    $HeadStyle += "tr:nth-child(odd) { background: #b8d1f3;}"
    $HeadStyle += "</style>"
    
    
    $props = [Ordered]@{'Status' = "Success"
                        'Message' = "Runbook Finished Successfully"                        
                        'SupersededUpdatesDeclined' = $DObject.SupersededUpdatesDeclined
                        'ExpiredUpdatesDeclined' = $DObject.SupersededUpdatesDeclined
                        'ObsoleteUpdatesDeleted' = $DObject.SupersededUpdatesDeclined
                        'UpdatesCompressed' = $DObject.SupersededUpdatesDeclined
                        'ObsoleteComputersDeleted' = $DObject.SupersededUpdatesDeclined
                        'DiskSpaceFreed' = $DObject.SupersededUpdatesDeclined}
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

    # Return values used for further processing, add properties if needed
    $props = [Ordered]@{'Status' = $status
                        'Message' = $excep
                        'ObjectCount' = 0}
    
    Write-Error $status
}
finally
{
    $props.Add('Trace',$trace)
    $props.Add('RunbookName',$RunbookName)

    $out = New-Object -TypeName PSObject -Property $props | ConvertTo-Html -Head $HeadStyle -Body "<h2>$($ENV:ComputerName) WSUS Report: $(Get-Date)</h2>"

    # optional, use Send-Email to send email or sms notifications, for sms use EmailAddressTo file with +45xxxxxxxx@sms.ecco.local
    .\Send-Email.ps1 -EmailAddressTO $(Get-AutomationVariable -Name "Email-PJE") -Subject "Runbook - $RunbookName Status" -Body $out -AsHtml

    Write-Output $out
}  