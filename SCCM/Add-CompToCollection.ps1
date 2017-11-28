Import-Module configurationmanager

$CollectionName = "ECCO DirectAccess Migrations Script 1.0 ENU"

$Computers = (Get-Content C:\Scripts\comp.txt)

Foreach ($Computer in $Computers)
{  
   add-cmdevicecollectiondirectmembershiprule -collectionname $CollectionName -resourceid (Get-CMDevice -name $Computer).ResourceID
}	