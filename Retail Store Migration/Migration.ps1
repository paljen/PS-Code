

Import-Module Scorch

$dc = "dkhqdc02.prd.eccocorp.net"
$rbServer = "DKHQSCORCH01.PRD.ECCOCORP.NET"      
$rbWebURL = New-SCOWebserverURL -ServerName $rbServer

Function SwitchMailbox()
{
    param(
    
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [String]$OldAccountName,

        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [String]$NewAccountName
    )

    Process
    {   
        Get-Mailbox -Identity $OldAccountName | Select Name,Guid,ExchangeGUID,ArchiveGuid | Out-File "$path\$(get-date -Format yyyyMMddhhmm).txt" -Append

        $rbGuid = "97bc3d18-c187-4d2c-aaaa-50ced631f37f" # Component - Detach and attach mailbox

        $rbparams = @{'OldUser'=$OldAccountName
                      'NewUser'=$NewAccountName
                      'DomainController'=$dc} 

        ## Call Scorch Runbook runbook to finish
        Start-SCORunbook -webserverURL $rbWebURL -RunbookGuid $rbGuid -InputParameters $rbparams
    }
}

Function MigrateO365
{
    param(
        
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [String]$UserPrincipalName
    )
    
    Process
    {
        $rbGuid = "876e5035-ab8f-4f11-b6a0-83925120a986" # Control – Migrate Retail User to Office365

        $rbparams = @{'UserPrincipalName'=$UserPrincipalName
                      'DomainController'=$dc
                      'TASKID'='100'}#>

        ## Call Scorch Runbook with computer data and wait for the runbook to finish
        Start-SCORunbook -webserverURL $rbWebURL -RunbookGuid $rbGuid -InputParameters $rbparams

    }
}


$path = Split-Path $MyInvocation.InvocationName
$users = Import-Csv $path\Users.csv


<### 1 ###
$users | SwitchMailbox

# Commands to check progress (exchange on-premise)
Get-MailboxRestoreRequest | Get-MailboxRestoreRequestStatistics | select targetali*,bytes*,status


### 2 ### Sync
.\Invoke-AzureADSync.ps1 -ComputerName DKHQAADS01 -SyncType Delta


### 3 ###

$users | MigrateO365

# Commands to check progress (exchange online)
Get-MoveRequest | ?{$_.displayname -like "ECCO fashion*"} | Get-MoveRequestStatistics | ft -autosize
Get-MoveRequest | ?{$_.displayname -like "ECCO hillsdale*"} | Get-MoveRequestStatistics | select *


(Get-MoveRequestStatistics -Identity usstore1001 -IncludeReport).Report.Failures | select -expand datacontext
(Get-MoveRequestStatistics -Identity usstore1017 -IncludeReport).Report.Baditems

Get-MoveRequest | ?{$_.displayname -like "ECCO*"} | Remove-MoveRequest
Get-MoveRequest | ?{$_.displayname -like "ECCO hillsdale*"} | Remove-MoveRequest
get-MoveRequest -MoveStatus Completed |Remove-MoveRequest -confirm $false

### 4 ### Sync
.\Invoke-AzureADSync.ps1 -ComputerName DKHQAADS01 -SyncType Delta

Remove-Module tmp*
Get-PSSession | Remove-PSSession
#>

# if error occoured log files will be generated, look for newest timestamp 
# \\prd\it\Automation\Automation.Workspace\Logs