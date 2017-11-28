$result = Get-WsusServer -Name dkhqsccm02 -PortNumber 8530 | Invoke-WsusServerCleanup –CleanupObsoleteUpdates
$result2 = Get-WsusServer -Name dkhqsccm02 -PortNumber 8530 | Invoke-WsusServerCleanup –CleanupUnneededContentFiles
$result3 = Get-WsusServer -Name dkhqsccm02 -PortNumber 8530 | Invoke-WsusServerCleanup -DeclineExpiredUpdates
$result4 = Get-WsusServer -Name dkhqsccm02 -PortNumber 8530 | Invoke-WsusServerCleanup –DeclineSupersededUpdates
$result5 = Get-WsusServer -Name dkhqsccm02 -PortNumber 8530 | Invoke-WsusServerCleanup –CompressUpdates

#Get-WsusServer | Invoke-WsusServerCleanup –CleanupObsoleteUpdates -CleanupUnneededContentFiles -CompressUpdates -DeclineExpiredUpdates -DeclineSupersededUpdates 
