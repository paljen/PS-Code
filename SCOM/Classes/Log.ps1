Class Log
{  
    [String]$Message
    [DateTime]$TimeStamp
    hidden [System.Collections.ArrayList]$Log = @()
    hidden [String]$LogFilePath

    Log()
    {

    }

    Log([String]$LogFilePath)
    {
        $this.LogFilePath = $LogFilePath
    }
   
    Log([DateTime]$TimeStamp,[String]$Message)
    {
        $this.TimeStamp = $TimeStamp
        $this.Message = $Message
    }

    WriteLogOutput([String]$Message)
    {
        $msg = "<![LOG[$($Message)]LOG]!>"
        $msg +="<time=`"$(Get-Date -Format HH:mm:ss.000+000)`" date=`"$(Get-Date -Format MM-dd-yyyy)`""
        $msg +=" component=`"`" context=`"`" type=`"`" thread=`"`" file=`"`">"

        add-content $this.LogFilePath -Value $msg
    }

    WriteLogEntry([String]$Message)
    {
       $this.Log.Add([Log]::new([DateTime]::Now,$Message))
       $this.WriteLogOutput($Message)
    }    
}