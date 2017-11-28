<# 
           .SYNOPSIS  
           This script will Pull or drain cluster resources from the command line. 
 
           .DESCRIPTION 
           The script will Pull or drain cluster resources from the command line. 
		   
		   .NOTES 
           File Name : ClusterResourceMover2.ps1
           Authors   : Mark Harris
           Requires  : Windows Server 2012 R2 PowerShell
                       Windows Server 2012 R2 Clustering Cmdlets 
                       Windows Server 2008 R2 PowerShell
					   Windows Server 2008 R2 Clustering Cmdlets 
           Version   : 1.0 (July 26 2016)
					   1.1 (August 22, 2016) Added FuncMail to send notifications
					        
           .PARAMETER drain or pullall 
           Specifies send, retrieve or delegate cluster resources 
 
           .INPUTS 
           ClusterResourceMover2 accepts drain and pullall 
 
           .OUTPUTS 
           Log to c:\support directory and log to EventLog and sends email to teams / individuals. 
 
           .EXAMPLE 
           C:\PS> .\ClusterResourceMover2 drain # drains all cluster resources to the other node. 
			
		   .EXAMPLE 
           C:\PS> .\ClusterResourceMover2 pullall # Retrives all cluster resources to the current node.
		   
#> 
# Get User input and execute function Must be first line in code

Param([Parameter(Mandatory=$true,HelpMessage="Enter in drain, pullall")][String]$ClusOp)

# Create Local logfile
$node = hostname
$date1=Get-Date -Format "yyyy-MM-dd hh:mm tt"
$clustervip=Get-Cluster 
$clustervipname=($clustervip.Name)
$admin = (Get-Content -Path env:username).ToString()
$LogFileName = "c:\Support\ClusterResMove-"+ $node +".txt"
Out-File -append -FilePath $LogFileName -Encoding ASCII
Add-Content -Path $LogFileName -Value "Computer: $node" -Encoding ASCII
Add-Content -Path $LogFileName -Value "*****************************" -Encoding ASCII


Function Drain {
Write-EventLog -LogName "Application" -Source "ServerMaint" -EventID 101 -EntryType Information -Message "Cluster Drain Operation started for Windows Patching"
Import-Module FailoverClusters
Add-Content -Path $LogFileName -Value "Date: $date1" -Encoding ASCII
Add-Content -Path $LogFileName -Value "Executed By: $admin" -Encoding ASCII
Add-Content -Path $LogFileName -Value "Current Cluster Assignments" -Encoding ASCII
Get-ClusterGroup | Out-File -append  -Encoding ASCII -FilePath $LogFileName 
$computer = get-content env:computername
$computer = $computer.ToLower()
$destnode = Get-clusternode | select Name

# Convert to string for use in foreach-object
[string]$drainnode = ($destnode.Name -ne $computer) 

Get-ClusterGroup |
foreach-object `
	{
	If ($_.Name -ne $computer)
		{
		Move-ClusterGroup -Name $_.Name -Node $drainnode
		}
	
	}
	
Add-Content -Path $LogFileName -Value "($clustervipname) Drain Operation Completed to $drainnode " -Encoding ASCII
Add-Content -Path $LogFileName -Value "New Cluster Assignments" -Encoding ASCII
Get-ClusterGroup | Out-File -append  -Encoding ASCII -FilePath $LogFileName
Write-EventLog -LogName "Application" -Source "ServerMaint" -EventID 201 -EntryType Information -Message "($clustervipname) Cluster Drain Operation completed for Windows Patching"
FuncMail -To "toemail.com" -From "myemail.com"  -Subject "($clustervipname) Cluster Drain Opertaion completed by ($node)." -Body "($clustervipname) Cluster Drain Operation completed for Windows Patching" -smtpServer "mgds.td.afg"
}

Function PullAll {
Write-EventLog -LogName "Application"  -Source "ServerMaint" -EventID 101 -EntryType Information -Message "Cluster PullAll Operation Started for Windows Patching"
Import-Module FailoverClusters
Add-Content -Path $LogFileName -Value "Date: $date1" -Encoding ASCII
Add-Content -Path $LogFileName -Value "Executed By: $admin" -Encoding ASCII
Add-Content -Path $LogFileName -Value "Current Cluster Assignments" -Encoding ASCII
Get-ClusterGroup | Out-File -append  -Encoding ASCII -FilePath $LogFileName 
$computer = get-content env:computername
$computer = $computer.ToLower()
Get-clusternode | Get-ClusterGroup |
foreach-object `
	{
	
	If ($_.Name -ne $computer)
		{ 
		Move-ClusterGroup -Name $_.Name -Node $computer
		}
	}
Add-Content -Path $LogFileName -Value "($clustervipname) PullAll Operation Completed to $computer " -Encoding ASCII
Add-Content -Path $LogFileName -Value "New Cluster Assignments" -Encoding ASCII
Get-ClusterGroup | Out-File -append  -Encoding ASCII -FilePath $LogFileName
Write-EventLog -LogName "Application" -Source "ServerMaint" -EventID 201 -EntryType Information -Message "($clustervipname) Cluster PullAll Operation completed for Windows Patching"
FuncMail -To "toemail.com" -From "myemail.com"  -Subject "($clustervipname) Cluster PullAll Opertaion completed by ($node)." -Body "($clustervipname) Cluster PullAll Operation completed for Windows Patching" -smtpServer "mgds.td.afg"
}

# Take the parameter and validate the input and call the functions.
If ("drain","pullall" -NotContains $ClusOp) 
  { 
    Throw "Not a valid option! Please use drain, pullall or balance option" | Out-File -append  -Encoding ASCII -FilePath $LogFileName 
  } 

function FuncMail {
    #param($strTo, $strFrom, $strSubject, $strBody, $smtpServer)
    param($To, $From, $Subject, $Body, $smtpServer)
    $msg = new-object Net.Mail.MailMessage
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
    $msg.From = $From
    $msg.To.Add($To)
    $msg.Subject = $Subject
    $msg.IsBodyHtml = 1
    $msg.Body = $Body
    $smtp.Send($msg)
}
  
 # All parameters are valid call function 
If ($ClusOp -eq "drain") { Drain }
If ($ClusOp -eq "pullall") { PullAll }
