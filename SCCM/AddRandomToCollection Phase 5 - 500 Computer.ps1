import-module "I:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
cd P01:

$CollectionID = "P010023F"
$NewCollection = "P010023E"
$CollectionSize = 500
$Computers = Get-CMDevice -CollectionID $CollectionID | Select-Object ResourceID

$RandomComputers = $Computers | get-random -Count $CollectionSize

foreach ($ResourceID in $RandomComputers) {
    Add-CMDeviceCollectionDirectMembershipRule -CollectionID $NewCollection -ResourceID $ResourceID.ResourceID
}


