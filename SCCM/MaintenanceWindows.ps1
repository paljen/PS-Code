import-module "I:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
cd P01:
$MW=Import-CSV "C:\Scripts\MainetenanceWindows.csv" -Delimiter ";"

#Parameters Get
    $MonthArray = New-Object System.Globalization.DateTimeFormatInfo 
    $MonthNames = $MonthArray.MonthNames 
    	
    Function Get-PatchTuesday
     { 
        $FindNthDay=2 #Aka Second occurence 
        $WeekDay='Tuesday' 
        $Today=get-date
        $todayM=$Today.Month.ToString() 
        $todayY=$Today.Year.ToString() 
        [datetime]$StrtMonth=$todayM+'/1/'+$todayY 
        while ($StrtMonth.DayofWeek -ine $WeekDay ) { $StrtMonth=$StrtMonth.AddDays(1) } 
        $PatchDay=$StrtMonth.AddDays(7*($FindNthDay-1)) 
        Return $PatchDay 
     }
	
    Function Set-PatchMW
        { 
 			Foreach ($MWName in $MW)
    			{
        		#Set Patch Tuesday for each Month 
        		$PatchDay=Get-PatchTuesday	##	($PatchMonth)	## No longer used as script uses Current month 
         
        		#Set Maintenance Window Naming Convention (Months array starting from 0 hence the -1)
                $todayM=$PatchDay.Month.ToString()
        		$MWDisplayName = $MonthNames[$PatchDay.Month-1]+" MaintenanceWindow "+$MWName.Name+" "+$MWName.CollectionID
 
		        #Set Device Collection Maintenace interval
        		$StartTime=$PatchDay.AddDays($MWName.OffSetDay -as [int]).Addhours($MWName.StartOffset -as [int])
		        $EndTime=$StartTime.Addhours(2)
                $OffsetW=$MwName.OffsetWeek -as [int]
                $OffsetD=$MwName.OffsetDay -as [int]
 
        		#Create The Schedule Token  
       			$Schedule = New-CMSchedule -Nonrecurring -Start $StartTime.AddDays($OffsetW*7) -End $EndTime.AddDays($OffsetW*7) 
 
		        #Set Maintenance Windows 
        		New-CMMaintenanceWindow -CollectionID $MWName.CollectionID -Schedule $Schedule -Name $MWDisplayName
        		} 
         }
		 
    #Remove all existing Maintenance Windows for a Collection 
    Function Remove-MaintnanceWindows  
        {
			Foreach ($MWName in $MW)
    		{
		    Get-CMMaintenanceWindow -CollectionId $MWName.CollectionID | ForEach-Object { 
        	Remove-CMMaintenanceWindow -CollectionID  $MWName.CollectionID -Name $_.Name -Force 
        	$Coll=Get-CMDeviceCollection -CollectionId $MWName.CollectionID 
        	Write-Host "Removing MW:"$_.Name"- From Collection:"$Coll.Name 
    		} 
			} 
 		}

     #List Current maintenance windows for all collections in the CSV 
    Function List-MaintenanceWindows
        {
        Foreach ($MWName in $MW)
    		{
		    $array +=Get-CMMaintenanceWindow -CollectionId $MWName.CollectionID | Format-Table Name, Description, StartTime, Duration -AutoSize
			} 
 		$array
        }

    Remove-MaintnanceWindows
    Set-PatchMW
    List-MaintenanceWindows
    Pause