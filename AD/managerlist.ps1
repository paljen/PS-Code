$res = @()

get-adgroupmember "o_sec-global external users" | foreach {
    
    $props = @{'User'=$_.Name}
    $usr = get-aduser $_.SamAccountName  -Properties "manager"
    $props.add('Manager',((($usr |select manager) -split "," | select -First 1)) -replace "@{manager=CN=")
    $props.add('Enabled',$usr.Enabled)
    $res += New-Object -TypeName PSObject -Property $props

}

$res | Export-Csv -Encoding UTF8 -Path C:\Temp\manager.csv -NoTypeInformation