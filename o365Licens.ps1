$user = @()

get-content C:\Temp\LicUsers.txt | foreach {
    try{
        $props = @{}
        $props.Add('UserPrincipalName',$_) 
        $LicId = (Get-MsolUser -UserPrincipalName $_).Licenses.AccountSkuId
        $props.Add('License',$LicId)
        $user += New-Object -TypeName PSObject -Property $props
        
        #Set-MsolUserLicense -UserPrincipalName asc@ecco.com -RemoveLicenses ecco:ENTERPRISEPREMIUM_NOPSTNCONF

        #Set-MsolUserLicense -UserPrincipalName $_ -AddLicenses ecco:ENTERPRISEPACK
    }
    catch
    {
        write-output "$($_) - $($_.exception.message)"
    }
}


Write-Output $user

#ecco:ENTERPRISEPREMIUM_NOPSTNCONF
#(Get-MsolUser -UserPrincipalName SOES@ecco.com).licenses
#$user = .\Set-O365License.ps1 -UserPrincipalName BESC@ecco.com -AssignIfLicensed $false -LicenseType E3-Full -UpdateSameLicense $true

#(get-msoluser -UserPrincipalName pje@ecco.com).licenses.accountskuid
(get-msoluser -UserPrincipalName jebe@ecco.com).licenses.accountskuid

get-content C:\Temp\E5License.txt | foreach {
    Set-EcMsolUserLicense -UserPrincipalName $_ -AssignIfLicensed $True -UpdateSameLicense $false -LicenseType E5-Full
}
