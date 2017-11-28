Param
(
	#User Principal Name of the user [xxx@xxx.xxx]
	[Parameter(Mandatory=$true)]
	[bool]$ForceADUpdate,

	#User Principal Name of the user [xxx@xxx.xxx]
	[Parameter(Mandatory=$true)]
	[bool]$AssignLicenses,

	#User Principal Name of the user [xxx@xxx.xxx]
	[Parameter(Mandatory=$true)]
	[bool]$RemoveLicenses
)

Start-Transcript -Path "C:\Automation\Scripts\Scheduled\AssignO365Licenses\Log\Log$(Get-Date -Format "yyyy-MM-dd_hh-mm-ss").log"
#$Global:ModuleRepository = "\\prd\it\Automation\Repository\Modules"
#import-module -name \\prd\it\Automation\Repository\Modules\Ecco.MSOnline
. \\prd\it\Automation\Repository\Modules\Ecco.MSOnline\1.0.0\Scripts\func.pje.msonline.ps1
. \\prd\it\Automation\Repository\Modules\Ecco.MSOnline\1.0.0\Scripts\func.skja.msonline.ps1
connect-ecmsolservice

#First loop through all MSOL Users and update AD with licenses assigned if applicable.
#region Update AD with MSOL license information
Write-Output "Getting MSOL Users..."
$msolusers = Get-MsolUser -All

Write-Output "...$($msolusers.count) MSOL users found, processing..."
foreach ($msoluser in $msolusers) {
    $msDSCloudAtrib1 = $null
    $msDSCloudAtrib2 = $null
    if (!$msoluser.licenses) {
        Write-Verbose "O365 USER: $($msoluser.userprincipalname) has no licenses"
    }
    else {
        $Licenses = @()
        foreach ($license in $msoluser.licenses) {
            $FriendlyLicense = Get-EcMsolLicenseProfile -LicenseSKU $license.AccountSkuId
            $Licenses += $FriendlyLicense
        }
        $Licenses = $Licenses | sort
        $msDSCloudAtrib1 = $Licenses -join ","
        Write-Verbose "O365 USER: $($msoluser.userprincipalname) has licenses $($licenses -join ",")" 
    }

    #Update AD?
    if ($ForceADUpdate -eq $true) {
        $ADUser = Get-ADUser -filter {UserPrincipalName -eq $msoluser.UserPrincipalName} -Properties msDS-cloudExtensionAttribute1, msDS-cloudExtensionAttribute2, UserPrincipalName, Enabled, CanonicalName
        if($ADUser) {
            $ADUser."msDS-cloudExtensionAttribute1" = $msDSCloudAtrib1
            if (!$msDSCloudAtrib1) {
                $ADUser."msDS-cloudExtensionAttribute2" = $msDSCloudAtrib2
            }
            Set-aduser -Instance $ADUser
            Write-Verbose "AD USER: $($msoluser.userprincipalname) cloud attribute 1 and 2 updated."
        }
        else {
            Write-Verbose "AD USER: $($msoluser.userprincipalname) not found in AD"
        }
    }

}
#endregion


#Then get all unlicensed users in the OU=ECCO,DC=prd,DC=eccocorp,DC=net OU which are 1) Enabled 2) Has a employeeID 3) has no license in msDs-CloudExtensionAttribute1 4) Are not placed in "Terminated Users" OU
#region Assign license to unlicensed AD Users
Write-Output "Getting AD Users..."
$ADUsers = get-aduser -SearchBase "OU=ECCO,DC=prd,DC=eccocorp,DC=net" -Filter {Enabled -eq $True -AND ObjectClass -eq 'User'} -properties * | ?{$_.EmployeeId -ne $null -AND $_.DistinguishedName -notlike "*OU=Terminated Users,OU=ECCO,DC=prd,DC=eccocorp,DC=net"} | select UserPrincipalName,msDS-cloudExtensionAttribute1, msDS-cloudExtensionAttribute2, Enabled, EmployeeId, c
$unlicensedusers = $ADUsers | ? msDS-cloudExtensionAttribute1 -eq $null
Write-Output "...$(($unlicensedusers).count) unlicensed AD Users Found..."

if ($AssignLicenses -eq $true) {
    Write-Output "...Assigning licences"
    Foreach ($unlicenseduser in $unlicensedusers) {
        #Update usage location to ADusers c attribute.
        Write-Output "...Assigning licence to $($unlicenseduser.userprincipalname)"
        $res = Set-EcMsolUserLocation -UserPrincipalName $unlicenseduser.UserPrincipalName -UsageLocation $unlicenseduser.c

        #Assign License (Also assign EMS license)
        $res = Set-EcMsolUserLicense -UserPrincipalName $unlicenseduser.UserPrincipalName -LicenseType E3-Full -AssignIfLicensed $false -UpdateSameLicense False
        $res = Set-EcMsolUserLicense -UserPrincipalName $unlicenseduser.UserPrincipalName -LicenseType EMS -AssignIfLicensed $true -UpdateSameLicense True
    }
}


#endregion

#region Remove license from disabled users where logondate -le 90 days from now
Write-Output "Getting disabled licensed Users..."
if ($RemoveLicenses -eq $true) {
    $disusers = get-aduser -SearchBase "OU=ECCO,DC=prd,DC=eccocorp,DC=net" -Filter {Enabled -eq $false} -properties * | ? {$_."msDs-cloudextensionattribute1" -ne $null} | select userprincipalname, enabled, msds-cloudextensionattribute1, msds-cloudextensionattribute2, c, lastlogondate
    $userstounlicense = $disusers | ? lastlogondate -le (get-date).AddDays(-90)
    Write-Output "...$(($userstounlicense).count) disabled licensed users found that has not been logged on for 90 days..."

    foreach ($user in $userstounlicense) {
        Write-Output "...Removing licence from $($user.userprincipalname)"
        Remove-EcMsolUserLicense -UserPrincipalName $user.userprincipalname -RemoveAll $True

        $upn = $user.userprincipalname
        $ADUser = Get-ADUser -filter {UserPrincipalName -eq $upn} -Properties msDS-cloudExtensionAttribute1, msDS-cloudExtensionAttribute2, UserPrincipalName, Enabled, CanonicalName
        $ADUser."msDS-cloudExtensionAttribute1" = $null
        $ADUser."msDS-cloudExtensionAttribute2" = $null
        Set-ADUser -Instance $ADUser
    }
}
#endregion

Stop-Transcript