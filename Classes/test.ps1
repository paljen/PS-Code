Class Log
{
    [DateTime]$TimeStamp
    [String]$Message

    Log()
    {
        
    }
   
    Log([DateTime]$TimeStamp,[String]$Message)
    {
        $this.TimeStamp = $TimeStamp
        $this.Message = $Message
    }

    [Log] WriteLogEntry([String]$Message)
    {
       return [Log]::new([DateTime]::Now,$Message)
    }
}

Class RunbookLog : Log
{
    [String]$RunbookName

    RunbookLog()
    {
    }

    RunbookLog([DateTime]$TimeStamp,[String]$RunbookName,[String]$Message)
    {
        $this.TimeStamp = $TimeStamp
        $this.Message = $Message
        $this.RunbookName = $RunbookName
    }

    [RunbookLog] WriteLogEntry([String]$RunbookName,[String]$Message)
    {
       return [RunbookLog]::new([DateTime]::Now,$RunbookName,$Message)
    }
}


[Array]$log = [RunbookLog]::New()
[System.Collections.ArrayList]$list = $log.Clone()
$list.Clear()
$list.Add($log.WriteLogEntry("Myrunbook","My message"))