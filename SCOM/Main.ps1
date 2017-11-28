


Param (
    
    [String]$AlertId,
    [String]$AlertName,
    [String]$AlertSeverity,
    [String]$AlertPriority,
    [String]$AlertState
)

$ErrorActionPreference = "Stop"

#$scriptPath = Split-path $($MyInvocation.InvocationName)
$scriptPath = "c:\powershell\SCOM"
. "$scriptpath\Classes\log.ps1"

$logName = "ForwardToAzure"
$logFile = "$scriptPath\$logName.Log"

# If the log file is larger then 2 MB rename the the file, a new log file will be gererated
Get-Item -Path $logFile -ErrorAction SilentlyContinue | ? {$_.length / 1KB -gt 2048} | Rename-Item -NewName $logName-$((get-date).tostring("MMddyyyyHHmm")).log

# Create new log instance
[Log]$Log = [Log]::new($logFile)

# Webhook token
$token = "P%2bRWjwXYpJtQT7ski8THvQy2IBnahtDj%2b7KS6lhihuE%3d"

# Webhook URI
$uri = "https://s2events.azure-automation.net/webhooks?token=$token"
$Log.WriteLogEntry("Webhook URI Interface: $uri")

# Headers
$headers = @{"Date"=[String]$(get-date)}
$Log.WriteLogEntry("REST Headers: $($headers | ConvertTo-Json))")

# Parameters
$params  = @{AlertId=$AlertId;
             AlertName=$AlertName;
             AlertSeverity=$AlertSeverity;
             AlertPriority=$AlertPriority;
             AlertState=$AlertState
}

# Convert Parameters to JSON to send as body
$body = ConvertTo-Json -InputObject $params
$Log.WriteLogEntry("REST Body: $body")

try
{
    $rest = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body -UseBasicParsing
    $Log.WriteLogEntry("Runbook successfully invoked, JobId: $($rest.JobIds)")
    
}
catch
{
    $Log.WriteLogEntry($($_.Exception.Message))
} 