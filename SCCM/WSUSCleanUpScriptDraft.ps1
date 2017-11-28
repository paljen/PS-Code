
            
    Add-Type -Path "C:\Program Files\Update Services\API\Microsoft.UpdateServices.Administration.dll"

    $UseSSL = $False

    $PortNumber = 8530

    $Server = "dkhqsccm02"

    #$ReportLocation = "C:\TEMP\WSUS_CleanUpTaskReport.html
    #$To = "pje@ecco.com"

    $WSUSConnection = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($Server,$UseSSL,$PortNumber)

    #Clean Up Scope

    $CleanupScopeObject = New-Object Microsoft.UpdateServices.Administration.CleanupScope
    $CleanupScopeObject.CleanupObsoleteComputers = $True
    $CleanupScopeObject.CleanupObsoleteUpdates = $True
    $CleanupScopeObject.CleanupUnneededContentFiles = $True
    $CleanupScopeObject.CompressUpdates = $True
    $CleanupScopeObject.DeclineExpiredUpdates = $True
    $CleanupScopeObject.DeclineSupersededUpdates = $True
    $CleanupTASK = $WSUSConnection.GetCleanupManager()
    #$Results = $CleanupTASK.PerformCleanup($CleanupScopeObject)


    $DObject = New-Object PSObject
    $DObject | Add-Member -MemberType NoteProperty -Name "SupersededUpdatesDeclined" -Value "1" #$Results.SupersededUpdatesDeclined
    $DObject | Add-Member -MemberType NoteProperty -Name "ExpiredUpdatesDeclined" -Value "1" #$Results.ExpiredUpdatesDeclined
    $DObject | Add-Member -MemberType NoteProperty -Name "ObsoleteUpdatesDeleted" -Value "1" #$Results.ObsoleteUpdatesDeleted
    $DObject | Add-Member -MemberType NoteProperty -Name "UpdatesCompressed" -Value "1" #$Results.UpdatesCompressed
    $DObject | Add-Member -MemberType NoteProperty -Name "ObsoleteComputersDeleted" -Value "1" #$Results.ObsoleteComputersDeleted
    $DObject | Add-Member -MemberType NoteProperty -Name "DiskSpaceFreed" -Value "1" #$Results.DiskSpaceFreed

    #HTML style
    $HeadStyle = "<style>"
    $HeadStyle += "h1, h5, th { text-align: center;}"
    $HeadStyle += "table { margin: auto; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey;}"
    $HeadStyle += "th { background: #0046c3; color: #fff; max-width: 400px; padding: 5px 10px;}"
    $HeadStyle += "td { font-size: 11px; padding: 5px 20px; color: #000;}"
    $HeadStyle += "tr { background: #b8d1f3;}"
    $HeadStyle += "tr:nth-child(even) { background: #dae5f4;}"
    $HeadStyle += "tr:nth-child(odd) { background: #b8d1f3;}"
    $HeadStyle += "</style>"
    
    
    $props = [Ordered]@{'Status' = "Success"
                        'Message' = "Runbook Finished Successfully"
                        'ObjectCount' = 1
                        'DObject' = $DObject}

    $obj = New-Object -TypeName PSObject -Property $props

    $Date = Get-Date
    $out = $obj | ConvertTo-Html -Head $HeadStyle -Body "<h2>$($ENV:ComputerName) WSUS Report: $date</h2>" #| Out-File $ReportLocation -Force



    #Send-MailMessage -To $To -from $FROM -subject "WSUS Clean Up Report" -smtpServer $SMTPServer -Attachments $ReportLocation -Port $SMTPPort 
    .\Send-Email.ps1 -EmailAddressTO 'pje@ecco.com' -Subject "Runbook - Status" -Body $out -AsHtml

