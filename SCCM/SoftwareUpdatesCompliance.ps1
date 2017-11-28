<#
	@viki 2016
    This script is provided as sample only, without any warranties
    Usage: Run following command line in an elevated CMD
	
	PowerShell.exe –ExecutionPolicy ByPass –nologo –noprofile –file <Path>\SU_Compliance_Client_v2.ps1 <computer name>
#>

Param
(
    [Parameter(Mandatory = $false)]
    [string]$ComputerName
)


$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrEmpty($ComputerName)) {$ComputerName = $env:COMPUTERNAME}
$OutputList = New-Object System.Collections.ArrayList

# Define Functions ----------------
function ConvertWMITimes ($obj)
{
    try {$obj = [System.Management.ManagementDateTimeConverter]::ToDateTime($obj)}
    catch {$obj = 'n/a'}
    return $obj
}

function Get-UpdateStore
{
    $filter = "ExcludeForStateReporting <> 'True'" # Exclude AV Definitions

    $Namespace = "Root\ccm\SoftwareUpdates\UpdatesStore"

    Try { 
        $UpdtStore = gwmi -Namespace $Namespace -ComputerName $ComputerName -Class "CCM_UpdateStatus" -Filter $filter | select Status, Article, Bulletin, ScanTime, Title, 
            ExcludeForStateReporting, UniqueID, RevisionNumber 
    }
    Catch {
	    write-host "Exception: $($_.Exception.Message)" -ForegroundColor Red
	    Break
    }

    if ($UpdtStore.count -eq 0) {break}

    # Convert WMI Times
    For ($i = 0; $i -lt $UpdtStore.count; $i++) 
    {
        write-progress -activity 'Importing data' -percentcomplete (($i + 1) / $UpdtStore.count * 100) -CurrentOperation ('Importing Update Store...'  + ($i + 1) + '/' + $UpdtStore.count)
        $UpdtStore[$i].ScanTime = ConvertWMITimes($UpdtStore[$i].ScanTime)
    }

    return $UpdtStore
}

function Get-StateMsg
{
    $Namespace = "Root\ccm\StateMsg"
    $filter = "TopicType = 500"

    Try { 
        $StateMsg = gwmi -Namespace $Namespace -ComputerName $ComputerName -class ccm_statemsg -filter $filter | select-object TopicID, MessageSent, MessageTime, StateID
    }
    Catch {
	    write-host "Exception: $($_.Exception.Message)" -ForegroundColor Red
	    Break
    }

    $StateMsgID = ('Detection state unknown', 'Not Required', 'Required', 'Installed')

    if ($StateMsg.count -eq 0) {return $StateMsg}
    for ($i = 0; $i -lt $StateMsg.count; $i++)
    {

        write-progress -activity 'Importing data' -percentcomplete (($i + 1) / $StateMsg.count * 100) -CurrentOperation ('Importing State Messages...'  + ($i + 1) + '/' + $StateMsg.count)

        # Convert WMI Times
        $StateMsg[$i].MessageTime = ConvertWMITimes($StateMsg[$i].MessageTime)

        # Correlate StateIDs
        $StateMsg[$i].StateID = $StateMsgID[$StateMsg[$i].StateID]
    }

    return $StateMsg
}

function Get-Deployments
{
    $Namespace = "Root\ccm\Policy\Machine\ActualConfig"

    Try { 
        $CIAssignments = gwmi -Namespace $Namespace -ComputerName $ComputerName -Class "CCM_CIAssignment" -Filter "__class = 'CCM_UpdateCIAssignment'"
    }
    Catch {
	    write-host "Exception: $($_.Exception.Message)" -ForegroundColor Red
	    Break
    }

    return $CIAssignments
}
# ---------------

$UpdtStore = Get-UpdateStore
$StateMsg = Get-StateMsg
$SUDeployments = Get-Deployments

$reboot = ('No', 'On Workstations', 'On Servers', 'On Servers & Workstations')

$counter = 0

foreach ($Update in $UpdtStore)
{
    $counter++
    write-progress -activity 'Importing data' -percentcomplete ($counter / $UpdtStore.count * 100) -CurrentOperation ('Merging data...'  + $counter + '/' + $UpdtStore.count)

    # Match corresponding State Msg 
    $msgIndex = [array]::IndexOf($StateMsg.TopicID, $Update.UniqueID)

    # Match corresponding Deployment
    $Deployment = New-Object System.Collections.ArrayList
    $dStart = New-Object System.Collections.ArrayList
    $dEnforce = New-Object System.Collections.ArrayList

    foreach ($assignment in $SUDeployments)
    {
        if ($assignment.AssignedCIs -match $Update.UniqueID) 
        {
            [void]$Deployment.Add($assignment)
            $dStart += ConvertWMITimes($assignment.StartTime)
            $dEnforce += ConvertWMITimes($assignment.EnforcementDeadline)
        }
    }

    $hash = 
        @{
            Status = $Update.Status
            #InstallDate = $qfe.InstalledOn
            KB = $Update.Article
            Bulletin = $Update.Bulletin
            LastScan = $Update.ScanTime
            Title = $Update.Title
            UpdateUniqueID = $Update.UniqueID
            Revision = $Update.RevisionNumber
            #ExcludeForStateReporting = $Update.ExcludeForStateReporting
        }

        # Add Status Msg Info
        if ($msgIndex -ne -1)
        {
            $hash.Add("uID", $StateMsg[$msgIndex].TopicID) # Should match the Update Unique ID
            $hash.Add("LastStateMsgSent", $StateMsg[$msgIndex].MessageTime)
            $hash.Add("Compliance", $StateMsg[$msgIndex].StateID)
        }
        else
        {
            $hash.Add("sID", 'n/a')
            $hash.Add("LastMsgSent", 'n/a')
            $hash.Add("Compliance", 'n/a')

        }

        # Add Deployment Info
        if ($Deployment.Count -gt 0)
        {
            $hash.Add("IsDeployed", $Deployment.count)
            $hash.Add("DeploymentName", $Deployment.AssignmentName)
            $hash.Add("DeploymentUniqueID", $Deployment.AssignmentID)
            $hash.Add("IgnoreMW", $Deployment.OverrideServiceWindows)
            $hash.Add("RebootOofMW", $Deployment.RebootOutsideOfServiceWindows)
            $hash.Add("AvailableAfter", $dStart)
            $hash.Add("Deadline", $dEnforce)
            $hash.Add("SuppressReboot", $reboot[$Deployment.SuppressReboot])
        }
        else
        {
            $hash.Add("IsDeployed", "No")
            $hash.Add("DeploymentName", "n/a")
            $hash.Add("DeploymentUniqueID", "n/a")
            $hash.Add("IgnoreMW", "n/a")
            $hash.Add("RebootOofMW", "n/a")
            $hash.Add("AvailableAfter", "n/a")
            $hash.Add("Deadline", "n/a")
            $hash.Add("SuppressReboot", "n/a")
        }

        $obj = New-Object PSObject -Property $hash
        [void]$OutputList.Add($obj)
    
}

Try {
    write-progress -activity 'Importing data' -Completed
}
catch {}

$OutputList | select Compliance, KB, Revision, Bulletin, IsDeployed, AvailableAfter, Deadline, LastScan, 
    LastStateMsgSent, Title, DeploymentName, IgnoreMW, RebootOofMW, SuppressReboot, UpdateUniqueID, 
    DeploymentUniqueID | sort IsDeployed, DeploymentName | ogv -Title "Software Updates Compliance" -PassThru

$OutputList | Export-csv -Path ($env:windir + '\temp\' + $ComputerName + '_SoftwareUpdates_Compliance.csv') -NoTypeInformation –Force -UseCulture
Write-Host 'List exported to ' -NoNewline
Write-Host ('%windir%\temp\' + $ComputerName + '_SoftwareUpdates_Compliance.csv') -ForegroundColor Green

Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0 # Remove declared variables

