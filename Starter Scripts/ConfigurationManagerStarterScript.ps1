
$sccmServer = "DKHQSCCM02"

$session = New-PSSession -ComputerName $sccmServer

Invoke-Command -Session $session -ScriptBlock {
    Import-Module ConfigurationManager
    cd P01:
}

Remove-PSSession -Session $session
