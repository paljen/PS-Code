
$minutespan = 15
$sitecode = "P01"
$serverName = "DKHQSCCM02"
$starttime = Get-Date -Format yyyyMMddHHmmss.000000+***


# Get collection list
$col = Get-WmiObject -Namespace "root\sms\site_$($sitecode)" -Query "Select * from SMS_Collection where CollectionID like '$($sitecode)%'" -ComputerName dkhqsccm02

# extract objects
$col = $col | % {[wmi]$_.__path}

# go through each wmi object and select those of type periodic with interval between 6-14 minutes
# the reason to start at 6 is that we dont want collections that are set to incremential update, witch is 5 min by default
$res = $col | Foreach {
       
        if ($_.refreshtype -eq 2 -and $_.refreshschedule.minutespan -gt 5 -and $_.refreshschedule.minutespan -lt 15)
        {
            $_ | select @{l='Name';e={($_.name)}},@{l='CollectionID';e={($_.CollectionID)}},@{l='RefreshType';e={($_.refreshtype)}},@{l='RefreshMinuteSpan';e={($_.refreshschedule.minutespan)}}
        }
    }

# Create refresh interval scriptblock and execute
$refresh = &{
            
            $intervalClass1 = [WMICLASS]("\\$($serverName)\root\sms\site_$($sitecode):SMS_ST_RecurInterval")
            $interval1 = $intervalClass.CreateInstance()
            $interval1.minutespan = $minutespan
            $interval1.starttime = $starttime
            $interval1
}

# go through the filtered list and set refresh schedule to the desired minutespan
$res | foreach {
    $collectionID = $_.collectionID
    #
    $coll = [wmi]"\\$($serverName)\root\sms\site_$($sitecode):sms_collection.collectionID='$($collectionID)'"
    $coll.RefreshSchedule = $refresh
    $coll.psbase
    $coll.Put()#>
}

$res | Sort RefreshMinuteSpan | ft -AutoSize