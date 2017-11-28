
 try
{
    try{
        [ADSI]::Exists("WinNT://localhost/Palle Jensen2,user")
    }
    catch{
        
        $objOu = [ADSI]"WinNT://$env:computername"
        $objUser = $objOU.Create("User","Palle Jensen")
        $objUser.SetPassword("Password1")   
        $objUser.SetInfo() 
    }

    $accountInstance = [ADSI]("WinNT://$accountName")

    if ($accountInstance.psbase.path -ne "WinNT://LocalAdmin")
    {
        
    }

    $groupInstance = [ADSI]("WinNT://$env:computername/$((gwmi win32_group -Filter "LocalAccount=$true" | ? {$_.sid -eq "S-1-5-32-544"}).name)")
    $trace += "$([dateTime]::Now) - gruppe reference $groupInstance`n"


    if(!($($groupInstance.Name) -ne "administratorer"))
    {
        $groupInstance.PSBase.Invoke("add",$accountInstance.psbase.path)   
    }
    
    if(!($($groupInstance.Name) -ne "administrators"))
    {
        $groupInstance.PSBase.Invoke("add",$accountInstance.psbase.path)   
    }   
}
catch
{
   $trace += "$([dateTime]::Now) - $($_.exception.message)`n"
}   
  


$usr = [ADSI]"WinNT://$env:computername/Palle Jensen"
$usr.UserFlags = 2
$usr.SetInfo()