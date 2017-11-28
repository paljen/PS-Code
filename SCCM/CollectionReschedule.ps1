



$sccmServer = "DKHQSCCM02"

$session = New-PSSession -ComputerName $sccmServer

Invoke-Command -Session $session -ScriptBlock {
    Import-Module ConfigurationManager
    cd P01:

     Import-CMComputerInformation -ComputerName PJETESTCOMP -MacAddress "A4-34-D9-6F-F9-20"
}

Remove-PSSession -Session $session
