
$ErrorActionPreference = "Stop"

$ComputerList = Get-Content C:\Temp\computers.txt

cd P01:

Foreach($Computer in $ComputerList)
{
    try
    {
        Add-CMDeviceCollectionDirectMembershipRule -CollectionID P01003D0 -ResourceId $(Get-CMDevice -Name $Computer).ResourceID
    }
    catch
    {
        "Error adding $computer to collection : $($_.exception.message)"
    }
}


