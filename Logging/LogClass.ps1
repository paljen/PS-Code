Class Logging
{
    [DateTime]$TimeStamp
    [String]$Message

    Logging()
    {
        $this.TimeStamp = $null
        $this.Message = $null
    }

    Logging([DateTime]$TimeStamp,[String]$Message)
    {
        $this.TimeStamp = $TimeStamp
        $this.Message = $Message
    }

    [Logging] WriteLogEntry([DateTime]$TimeStamp,[String]$Message)
    {
        return [Logging]::New([DateTime]$TimeStamp,[String]$Message)
    }
}


# Create New Logging Instance
[Logging[]]$LogInstance = [Logging]::New()

# Clone Logging Array to ArrayList to utalize array methods
[System.Collections.ArrayList]$Log = $LogInstance.Clone()

# Clear Log
$Log.clear()

# Creating a new log instance adding it to arraylist
$Log.Add($LogInstance.WriteLogEntry((Get-date),"ok2")) | Out-Null


$log | convertto-html | out-file C:\temp\trace.html

