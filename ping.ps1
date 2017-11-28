$err = @()
$ok = @()

Get-Content C:\temp\ |foreach {
    try
    {
           Test-Connection -ComputerName $_ -Count 1 -ErrorAction Stop
    }
    catch
    {
        $err += $error[0].Exception
    }
}

$ok.destination