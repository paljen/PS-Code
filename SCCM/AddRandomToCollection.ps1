import-module "I:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
cd P01:

$CollectionID = "P010023F"
$NewCollection = Read-host "Please provide Collection ID of the collection to Populate"
$CollectionSize = Read-host "Please enter the number of random computers to add to collection"
$Computers = Get-CMDevice -CollectionID $CollectionID | Select-Object ResourceID

$RandomComputers = $Computers | get-random -Count $CollectionSize

foreach ($ResourceID in $RandomComputers) {
    Add-CMDeviceCollectionDirectMembershipRule -CollectionID $NewCollection -ResourceID $ResourceID.ResourceID
}
