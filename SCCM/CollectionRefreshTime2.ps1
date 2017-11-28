
#$ns = gwmi -Namespace "root\CCM\SoftwareUpdates" -list | ? {$_ -match "CIM_"}
#Get-CimClass -Namespace "root\CCM\SoftwareUpdates" -ClassName CIM_Indication -PropertyName * |select -ExpandProperty cimclassproperties
 
$classes = Get-WmiObject -Namespace "root\sms\site_P01" -ComputerName dkhqsccm02 -list | ? {$_.name -match "SMS_"}
$classes.Count

$nspace = "root\sms\site_P01"
$comp = "DKHQSCCM02"
gwmi -Namespace $nspace -ComputerName $comp -Class sms_clientsettings


#$ns = $ns | % {[wmi]$_.__path}