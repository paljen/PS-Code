Class Log
{
    [DateTime]$TimeStamp
    [String]$Message

    Log()
    {
        $this.TimeStamp = $null
        $this.Message = $null
    }

    Log([DateTime]$TimeStamp,[String]$Message)
    {
        $this.TimeStamp = $TimeStamp
        $this.Message = $Message
    }

    [Log] WriteLogEntry([DateTime]$TimeStamp,[String]$Message)
    {
        return [Log]::New([DateTime]$TimeStamp,[String]$Message)
    }
}


<# Create New Logging Instance
[Log[]]$LogInstance = [Log]::New()

# Clone Logging Array to ArrayList to utalize array methods
[System.Collections.ArrayList]$Log = $LogInstance.Clone()

# Clear Log
$Log.clear()

# Creating a new log instance adding it to arraylist
$Log.Add($LogInstance.WriteLogEntry((Get-date),"ok2")) | Out-Null#>
