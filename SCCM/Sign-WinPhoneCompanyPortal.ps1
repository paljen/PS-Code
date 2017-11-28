<#
.NOTES
    Copyright © Microsoft.  All Rights Reserved.
    This code released under the terms of the 
    MIT License (MIT) - http://opensource.org/licenses/MIT

 .SYNOPSIS
    This script signs an .appx file for Windows Phone 8.1 sideloading using a Symantec Enterprise Mobile Code Signing Certificate.

 .DESCRIPTION
    This script signs an .appx file for Windows Phone 8.1 sideloading using a Symantec Enterprise Mobile Code Signing Certificate.
    This script requires the Windows SDK for Windows 8.1 be installed on the host computer.
    This script also requires an Application Enrollment Token (.aetx) file that is generated using your Symantec Enterprise Mobile Code Signing Certificate.
 
.PARAMETER InputAppx
    The path to where the source appx file is located.
.PARAMETER OutputAppx
    The output path for the signed appx file.
.PARAMETER PfxFilePath
    The path to Symantec Enterprise Mobile Code Signing Certificate (.PFX) file.
.PARAMETER AetxPath	
    The path to the .aetx file which is used for reading the enterprise ID if the 'EnterpriseId' argument is not defined. Either this argument or EnterpriseId must be provided.
.PARAMETER PublisherId
    The Publisher ID of the enterprise. If absent, the 'Subject' field of the Symantec Enterprise Mobile Code Signing Certificate is used.
.PARAMETER EnterpriseId
    The enterprise ID. Either this argument or 'AetxPath' must be provided. If this argument is not provided, the enterprise ID is read from the AETX file.
.PARAMETER SdkPath
    The path to the root folder of the Windows SDK for Windows 8.1. This argument is optional and defaults to ${env:ProgramFiles(x86)}\Windows Kits\8.1
.PARAMETER PfxPassword
    The password of the Symantec Enterprise Mobile Code Signing Certificate.

.LINK
    To download Windows SDK for Windows 8.1, visit http://go.microsoft.com/fwlink/?LinkId=613525

.LINK
    For more information on Symantec Enterprise Mobile Code Signing Certificates and signing process visit http://go.microsoft.com/fwlink/?LinkId=613524
    
.LINK
	For more information on how to generate an AETX file, visit http://go.microsoft.com/fwlink/?LinkId=615047.

.EXAMPLE
    .\Sign-WinPhoneCompanyPortal.ps1 -InputAppx 'C:\temp\CompanyPortal.appx' -OutputAppx 'C:\temp\CompanyPortalEnterpriseSigned.appx' -PfxFilePath 'C:\signing\cert.pfx' -PfxPassword '1234' -AetxPath 'C:\signing\cert.aetx'

    This example signs the CompanyPortal.appx at C:\temp\ and produces the CompanyPortalEnterpriseSigned.appx. It would use PFX password 1234 and read the publisher ID from the PFX file.
    It would read the enterprise ID from the cert.aetx file as well.

.EXAMPLE
    .\Sign-WinPhoneCompanyPortal.ps1 -InputAppx 'C:\temp\CompanyPortal.appx' -OutputAppx 'C:\temp\CompanyPortalEnterpriseSigned.appx' -PfxFilePath 'C:\signing\cert.pfx' -PfxPassword '1234' -PublisherId 'OID.0.9.2342.19200300.100.1.1=1000000001, CN="Test, Inc.", OU=Test 1' -EnterpriseId 1000000001

    This example signs the CompanyPortal.appx at C:\temp\ and produces the CompanyPortalEnterpriseSigned.appx. It would use PFX password 1234 and use the publisher ID specified.
#>
[CmdletBinding(DefaultParameterSetName="aetx")] 
Param(
    [string][Parameter(Mandatory=$true)][ValidateScript({if (Test-Path -PathType Leaf $_) {$true} else {Throw "The '$_' is not found or is not a file"}})] $InputAppx,
    [string][Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] $OutputAppx,
    [string][Parameter(Mandatory=$true)][ValidateScript({if (Test-Path -PathType Leaf $_) {$true} else {Throw "The '$_' is not found or is not a file"}})] $PfxFilePath,
    [string][Parameter(Mandatory=$true,ParameterSetName='aetx')][ValidateNotNullOrEmpty()] $AetxPath,
    [uint32][Parameter(Mandatory=$true,ParameterSetName='non-aetx')] $EnterpriseId,
    [string][Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()] $PublisherId,
    [string][Parameter(Mandatory=$false)][ValidateScript({if (Test-Path -PathType Container $_) {$true} else {Throw "The '$_' is not found or is not a directory"}})] $SdkPath = "${env:ProgramFiles(x86)}\Windows Kits\8.1",
    [string][Parameter(Mandatory=$false)] $PfxPassword
)

Set-StrictMode -Version Latest

# Stop execution on the first error since it doesn't make sense to continue.
$ErrorActionPreference = 'Stop'

$MakeAppxPath = "$SdkPath\bin\x86\MakeAppx.exe"
$SignToolPath = "$SdkPath\bin\x86\SignTool.exe"

# If publisher ID is not set, read it from the Symantec Enterprise Mobile Code Signing Certificate itself.
if(!$PublisherId)
{
    Add-Type -AssemblyName System.Security
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    try
    {
        if($PfxPassword)
        {
            $cert.Import($PfxFilePath, $PfxPassword, 'DefaultKeySet')
        }
        else
        {
            $cert.Import($PfxFilePath)
        }

        $PublisherId = $cert.Subject
    }
    catch [System.Security.Cryptography.CryptographicException]
    {
        Throw "Failed to read signing certificate: $_"
    }
    
    if(!$PublisherId)
    {
        Throw "Certificate does not contain a subject."
    }

    Write-Verbose "Publisher ID read from the certificate: $PublisherId"
}

# If the enterprise ID is not set, read it from AETX file.
if(!$EnterpriseId)
{
    $aetxContent = [xml](get-content $AetxPath)
    
    # Read enterprise ID from EnterpriseAppManagement node
    $enterpriseIdAetx = $aetxContent.SelectSingleNode('/wap-provisioningdoc/characteristic[@type="EnterpriseAppManagement"]/characteristic/@type').value
    
    # Read enterprise ID from the inner EnrollmentToken node
    $enrollmentToken = $aetxContent.SelectSingleNode('/wap-provisioningdoc/characteristic[@type="EnterpriseAppManagement"]/characteristic/parm[@datatype="string" and @name="EnrollmentToken"]/@value').value
    $aetXml = [xml]([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($enrollmentToken)))
    $enterpriseIdAet = [uint32]($aetXml.AET.EnterpriseId.Value)

    # Validate that the two IDs match
    if($enterpriseIdAetx -ne $enterpriseIdAet)
    {
        Throw "The Enterprise IDs read from AETX file are not consistent."
    }
    
    $EnterpriseId = [uint32]$enterpriseIdAetx

    Write-Verbose "Enterprise ID read from the AETX: $EnterpriseId"
}

# Create the phone publisher ID GUID based on enterprise ID.
$PhonePublisherId = New-Object Guid($EnterpriseId, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
Write-Verbose "The phone publisher ID to use in app manifest: $PhonePublisherId"

# Use a temp folder to unpack the AppX file.
$appxTempFolder = [IO.Path]::Combine([IO.Path]::GetTempPath(), [Guid]::NewGuid())

Write-Verbose "Extracting Appx '$InputAppx' to temp folder '$appxTempFolder'"
&"$MakeAppxPath" unpack /l /p "$InputAppx" /d "$appxTempFolder"
if(!$?)
{
    Throw "Failed to unpack the appx file."
}

# Edit AppxManifest.xml.
$appxManifestFile = [IO.Path]::Combine($appxTempFolder, "AppxManifest.xml")
$appxManifest = [xml](get-content $appxManifestFile)

$appxManifest.Package.Identity.Publisher = $PublisherId
Write-Verbose "Publisher is set to: $PublisherId"

$appxManifest.Package.PhoneIdentity.PhonePublisherId = [string]$PhonePublisherId
Write-Verbose "PhonePublisherId is set to: $PhonePublisherId"

Write-Verbose 'Saving changes to AppxManifest.xml'
$appxManifest.Save($appxManifestFile)

# Create the final appx file
&"$MakeAppxPath" pack /l /d "$appxTempFolder" /p "$OutputAppx" /o
if(!$?)
{
    Throw "Failed to repack the appx file."
}

# Sign the appx with the Symantec Enterprise Mobile Code Signing Certificate.
&"$SignToolPath" sign /fd sha256 /f "$PfxFilePath" /p "$PfxPassword" "$OutputAppx"
if(!$?)
{
    Throw "Failed to sign the appx file."
}

Write-Verbose 'Deleting the temp folder.'
Remove-Item -Recurse -Force $appxTempFolder

Write-Host 'Package signed for Windows Phone sideloading.'
# SIG # Begin signature block
# MIIkHwYJKoZIhvcNAQcCoIIkEDCCJAwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBQcvnYJfaCCl4a
# Z+hX8/p832Gutcf8VSPrv6+KAjrhBaCCDZIwggYQMIID+KADAgECAhMzAAAAZEeE
# lIbbQRk4AAAAAABkMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMTUxMDI4MjAzMTQ2WhcNMTcwMTI4MjAzMTQ2WjCBgzEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjENMAsGA1UECxMETU9Q
# UjEeMBwGA1UEAxMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMIIBIjANBgkqhkiG9w0B
# AQEFAAOCAQ8AMIIBCgKCAQEAky7a2OY+mNkbD2RfTahYTRQ793qE/DwRMTrvicJK
# LUGlSF3dEp7vq2YoNNV9KlV7TE2K8sDxstNSFYu2swi4i1AL3X/7agmg3GcExPHf
# vHUYIEC+eCyZVt3u9S7dPkL5Wh8wrgEUirCCtVGg4m1l/vcYCo0wbU06p8XzNi3u
# XyygkgCxHEziy/f/JCV/14/A3ZduzrIXtsccRKckyn6B5uYxuRbZXT7RaO6+zUjQ
# hiyu3A4hwcCKw+4bk1kT9sY7gHIYiFP7q78wPqB3vVKIv3rY6LCTraEbjNR+phBQ
# EL7hyBxk+ocu+8RHZhbAhHs2r1+6hURsAg8t4LAOG6I+JQIDAQABo4IBfzCCAXsw
# HwYDVR0lBBgwFgYIKwYBBQUHAwMGCisGAQQBgjdMCAEwHQYDVR0OBBYEFFhWcQTw
# vbsz9YNozOeARvdXr9IiMFEGA1UdEQRKMEikRjBEMQ0wCwYDVQQLEwRNT1BSMTMw
# MQYDVQQFEyozMTY0Mis0OWU4YzNmMy0yMzU5LTQ3ZjYtYTNiZS02YzhjNDc1MWM0
# YjYwHwYDVR0jBBgwFoAUSG5k5VAF04KqFzc3IrVtqMp1ApUwVAYDVR0fBE0wSzBJ
# oEegRYZDaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljQ29k
# U2lnUENBMjAxMV8yMDExLTA3LTA4LmNybDBhBggrBgEFBQcBAQRVMFMwUQYIKwYB
# BQUHMAKGRWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWlj
# Q29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNydDAMBgNVHRMBAf8EAjAAMA0GCSqG
# SIb3DQEBCwUAA4ICAQCI4gxkQx3dXK6MO4UktZ1A1r1mrFtXNdn06DrARZkQTdu0
# kOTLdlGBCfCzk0309RLkvUgnFKpvLddrg9TGp3n80yUbRsp2AogyrlBU+gP5ggHF
# i7NjGEpj5bH+FDsMw9PygLg8JelgsvBVudw1SgUt625nY7w1vrwk+cDd58TvAyJQ
# FAW1zJ+0ySgB9lu2vwg0NKetOyL7dxe3KoRLaztUcqXoYW5CkI+Mv3m8HOeqlhyf
# FTYxPB5YXyQJPKQJYh8zC9b90JXLT7raM7mQ94ygDuFmlaiZ+QSUR3XVupdEngrm
# ZgUB5jX13M+Pl2Vv7PPFU3xlo3Uhj1wtupNC81epoxGhJ0tRuLdEajD/dCZ0xIni
# esRXCKSC4HCL3BMnSwVXtIoj/QFymFYwD5+sAZuvRSgkKyD1rDA7MPcEI2i/Bh5O
# MAo9App4sR0Gp049oSkXNhvRi/au7QG6NJBTSBbNBGJG8Qp+5QThKoQUk8mj0ugr
# 4yWRsA9JTbmqVw7u9suB5OKYBMUN4hL/yI+aFVsE/KJInvnxSzXJ1YHka45ADYMK
# AMl+fLdIqm3nx6rIN0RkoDAbvTAAXGehUCsIod049A1T3IJyUJXt3OsTd3WabhIB
# XICYfxMg10naaWcyUePgW3+VwP0XLKu4O1+8ZeGyaDSi33GnzmmyYacX3BTqMDCC
# B3owggVioAMCAQICCmEOkNIAAAAAAAMwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29m
# dCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDExMB4XDTExMDcwODIwNTkw
# OVoXDTI2MDcwODIxMDkwOVowfjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEoMCYGA1UEAxMfTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAx
# MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKvw+nIQHC6t2G6qghBN
# NLrytlghn0IbKmvpWlCquAY4GgRJun/DDB7dN2vGEtgL8DjCmQawyDnVARQxQtOJ
# DXlkh36UYCRsr55JnOloXtLfm1OyCizDr9mpK656Ca/XllnKYBoF6WZ26DJSJhIv
# 56sIUM+zRLdd2MQuA3WraPPLbfM6XKEW9Ea64DhkrG5kNXimoGMPLdNAk/jj3gcN
# 1Vx5pUkp5w2+oBN3vpQ97/vjK1oQH01WKKJ6cuASOrdJXtjt7UORg9l7snuGG9k+
# sYxd6IlPhBryoS9Z5JA7La4zWMW3Pv4y07MDPbGyr5I4ftKdgCz1TlaRITUlwzlu
# ZH9TupwPrRkjhMv0ugOGjfdf8NBSv4yUh7zAIXQlXxgotswnKDglmDlKNs98sZKu
# HCOnqWbsYR9q4ShJnV+I4iVd0yFLPlLEtVc/JAPw0XpbL9Uj43BdD1FGd7P4AOG8
# rAKCX9vAFbO9G9RVS+c5oQ/pI0m8GLhEfEXkwcNyeuBy5yTfv0aZxe/CHFfbg43s
# TUkwp6uO3+xbn6/83bBm4sGXgXvt1u1L50kppxMopqd9Z4DmimJ4X7IvhNdXnFy/
# dygo8e1twyiPLI9AN0/B4YVEicQJTMXUpUMvdJX3bvh4IFgsE11glZo+TzOE2rCI
# F96eTvSWsLxGoGyY0uDWiIwLAgMBAAGjggHtMIIB6TAQBgkrBgEEAYI3FQEEAwIB
# ADAdBgNVHQ4EFgQUSG5k5VAF04KqFzc3IrVtqMp1ApUwGQYJKwYBBAGCNxQCBAwe
# CgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0j
# BBgwFoAUci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0fBFMwUTBPoE2gS4ZJaHR0
# cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2Vy
# QXV0MjAxMV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcBAQRSMFAwTgYIKwYBBQUH
# MAKGQmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2Vy
# QXV0MjAxMV8yMDExXzAzXzIyLmNydDCBnwYDVR0gBIGXMIGUMIGRBgkrBgEEAYI3
# LgMwgYMwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lv
# cHMvZG9jcy9wcmltYXJ5Y3BzLmh0bTBABggrBgEFBQcCAjA0HjIgHQBMAGUAZwBh
# AGwAXwBwAG8AbABpAGMAeQBfAHMAdABhAHQAZQBtAGUAbgB0AC4gHTANBgkqhkiG
# 9w0BAQsFAAOCAgEAZ/KGpZjgVHkaLtPYdGcimwuWEeFjkplCln3SeQyQwWVfLiw+
# +MNy0W2D/r4/6ArKO79HqaPzadtjvyI1pZddZYSQfYtGUFXYDJJ80hpLHPM8QotS
# 0LD9a+M+By4pm+Y9G6XUtR13lDni6WTJRD14eiPzE32mkHSDjfTLJgJGKsKKELuk
# qQUMm+1o+mgulaAqPyprWEljHwlpblqYluSD9MCP80Yr3vw70L01724lruWvJ+3Q
# 3fMOr5kol5hNDj0L8giJ1h/DMhji8MUtzluetEk5CsYKwsatruWy2dsViFFFWDgy
# cScaf7H0J/jeLDogaZiyWYlobm+nt3TDQAUGpgEqKD6CPxNNZgvAs0314Y9/HG8V
# fUWnduVAKmWjw11SYobDHWM2l4bf2vP48hahmifhzaWX0O5dY0HjWwechz4GdwbR
# BrF1HxS+YWG18NzGGwS+30HHDiju3mUv7Jf2oVyW2ADWoUa9WfOXpQlLSBCZgB/Q
# ACnFsZulP0V3HjXG0qKin3p6IvpIlR+r+0cjgPWe+L9rt0uX4ut1eBrs6jeZeRhL
# /9azI2h15q/6/IvrC4DqaTuv/DDtBEyO3991bWORPdGdVk5Pv4BXIqF4ETIheu9B
# CrE/+6jMpF3BoYibV3FWTkhFwELJm3ZbCoBIa/15n8G9bW1qyVJzEw16UM0xghXj
# MIIV3wIBATCBlTB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSgwJgYDVQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExAhMzAAAA
# ZEeElIbbQRk4AAAAAABkMA0GCWCGSAFlAwQCAQUAoIHOMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqG
# SIb3DQEJBDEiBCA91PAhmOi8hxS+G2jMZTPeZcvQDrDrwtlewcklX/M70jBiBgor
# BgEEAYI3AgEMMVQwUqA0gDIATQBpAGMAcgBvAHMAbwBmAHQAIABDAG8AcgBwAG8A
# cgBhAHQAaQBvAG4AIAAoAFIAKaEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20w
# DQYJKoZIhvcNAQEBBQAEggEAXj9k+ezzGWuJ7Qnt1yUG2Asdy3OWf+mlutrk95jQ
# G3EKFi1IHM+Vs+jEsCDEet8FUujCX6F88VYjSZ1q3BCtRCyUKc7LmXEUFCH50c1j
# 4Hhq94dYwcmEWhf4ylLHK4HcGPFEBL3MGaVDeLn8BNTCbporwFAKtw6Tw2isHkm4
# O/nT9ywhExoLqfT3Aulge833z4wIhhMsnwMOuiMgH4k51yXPYCDf1Qh1D21J+jXO
# wPcNYKnL9haXJfgnj+ue2rCjDOsJpAg+IAVmSwADzMPZqSAKoLVxqZ0IYFEnEB53
# fua7CRe3zyq0FYgiVQUd+R8SnNaZIUoAibjoCg/bCRXNP6GCE00wghNJBgorBgEE
# AYI3AwMBMYITOTCCEzUGCSqGSIb3DQEHAqCCEyYwghMiAgEDMQ8wDQYJYIZIAWUD
# BAIBBQAwggE9BgsqhkiG9w0BCRABBKCCASwEggEoMIIBJAIBAQYKKwYBBAGEWQoD
# ATAxMA0GCWCGSAFlAwQCAQUABCDb+4hKiEtLYImREFdcGNobbvu3XAVYsG6yLdgn
# xzkCgAIGVk9Car8zGBMyMDE1MTIwMzA3NDA0OS4xODhaMAcCAQGAAgH0oIG5pIG2
# MIGzMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMQ0wCwYDVQQL
# EwRNT1BSMScwJQYDVQQLEx5uQ2lwaGVyIERTRSBFU046N0QyRS0zNzgyLUIwRjcx
# JTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wggg7QMIIGcTCC
# BFmgAwIBAgIKYQmBKgAAAAAAAjANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJv
# b3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMTAwNzAxMjEzNjU1WhcN
# MjUwNzAxMjE0NjU1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCASIw
# DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKkdDbx3EYo6IOz8E5f1+n9plGt0
# VBDVpQoAgoX77XxoSyxfxcPlYcJ2tz5mK1vwFVMnBDEfQRsalR3OCROOfGEwWbEw
# RA/xYIiEVEMM1024OAizQt2TrNZzMFcmgqNFDdDq9UeBzb8kYDJYYEbyWEeGMoQe
# dGFnkV+BVLHPk0ySwcSmXdFhE24oxhr5hoC732H8RsEnHSRnEnIaIYqvS2SJUGKx
# Xf13Hz3wV3WsvYpCTUBR0Q+cBj5nf/VmwAOWRH7v0Ev9buWayrGo8noqCjHw2k4G
# kbaICDXoeByw6ZnNPOcvRLqn9NxkvaQBwSAJk3jN/LzAyURdXhacAQVPIk0CAwEA
# AaOCAeYwggHiMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBTVYzpcijGQ80N7
# fEYbxTNoWoVtVTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMC
# AYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvX
# zpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
# cGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYI
# KwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDCBoAYDVR0g
# AQH/BIGVMIGSMIGPBgkrBgEEAYI3LgMwgYEwPQYIKwYBBQUHAgEWMWh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9QS0kvZG9jcy9DUFMvZGVmYXVsdC5odG0wQAYIKwYB
# BQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AUABvAGwAaQBjAHkAXwBTAHQAYQB0AGUA
# bQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAAfmiFEN4sbgmD+BcQM9naOh
# IW+z66bM9TG+zwXiqf76V20ZMLPCxWbJat/15/B4vceoniXj+bzta1RXCCtRgkQS
# +7lTjMz0YBKKdsxAQEGb3FwX/1z5Xhc1mCRWS3TvQhDIr79/xn/yN31aPxzymXlK
# kVIArzgPF/UveYFl2am1a+THzvbKegBvSzBEJCI8z+0DpZaPWSm8tv0E4XCfMkon
# /VWvL/625Y4zu2JfmttXQOnxzplmkIz/amJ/3cVKC5Em4jnsGUpxY517IW3DnKOi
# PPp/fZZqkHimbdLhnPkd/DjYlPTGpQqWhqS9nhquBEKDuLWAmyI4ILUl5WTs9/S/
# fmNZJQ96LjlXdqJxqgaKD4kWumGnEcua2A5HmoDF0M2n0O99g/DhO3EJ3110mCII
# YdqwUB5vvfHhAN/nMQekkzr3ZUd46PioSKv33nJ+YWtvd6mBy6cJrDm77MbL2IK0
# cs0d9LiFAR6A+xuJKlQ5slvayA1VmXqHczsI5pgt6o3gMy4SKfXAL1QnIffIrE7a
# KLixqduWsqdCosnPGUFN4Ib5KpqjEWYw07t0MkvfY3v1mYovG8chr1m1rtxEPJdQ
# cdeh0sVV42neV8HR3jDA/czmTfsNv11P6Z0eGTgvvM9YBS7vDaBQNdrvCScc1bN+
# NR4Iuto229Nfj950iEkSMIIE2jCCA8KgAwIBAgITMwAAAHa2EOF8hyM8IgAAAAAA
# djANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAe
# Fw0xNTEwMDcxODE3NDBaFw0xNzAxMDcxODE3NDBaMIGzMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMQ0wCwYDVQQLEwRNT1BSMScwJQYDVQQLEx5u
# Q2lwaGVyIERTRSBFU046N0QyRS0zNzgyLUIwRjcxJTAjBgNVBAMTHE1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFNlcnZpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQCjBZPzdMhg4SzLUFt5DqieGdCP0iSjBmG6Vpa1OpQBouBn3ekRI/7+gmIZ
# Pw28hyeS5mZRUK73tRH7Bg6oo/cmW4Pvwm5Y6k3IU+uReBB1xga+g5DAabroWXd6
# 6Fp2sqpiA3HPU3jXlifYl363hIC/zDroVt40DbFF/AiAO5L8CjXK/FP1CHEfKmb0
# YFaOHTIcZB9coWklOZUdKlZ3cIe+cODGxW0YOaZD+U7qEi0GrmduMeqMrF+yD8Z7
# FgnTY/Bh6w5VY/VNqgDIGdO0ulECLa2SgW5shWZGkvOjLVNUSglB0uPLKI5tvlhk
# Ket3KHZi/2F8zvTD08G95Z3BYyGDAgMBAAGjggEbMIIBFzAdBgNVHQ4EFgQU9BSF
# SDz3+u+saA7QkanHq7QAXMswHwYDVR0jBBgwFoAU1WM6XIoxkPNDe3xGG8UzaFqF
# bVUwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3Br
# aS9jcmwvcHJvZHVjdHMvTWljVGltU3RhUENBXzIwMTAtMDctMDEuY3JsMFoGCCsG
# AQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNUaW1TdGFQQ0FfMjAxMC0wNy0wMS5jcnQwDAYDVR0TAQH/
# BAIwADATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkqhkiG9w0BAQsFAAOCAQEAWrRE
# oFh9Zd/7Q6t6mZoLzt10sGBOT5urnmMkgEjfStupcgIcg9odGZ0olgpL63Gqqi9A
# leZSh4oeD49zKTWTY8WMdDhy2rRHwYh4/driLNZJm5Hym3tZbHZkh7n4W19tw9fk
# 5YeS1iSi4YsHoWIVTr2+v/sFcd5AF/oZCT1XddsTJ2V3MwjBP7DU/Ym65ZyRUrOh
# uLzcfz02u21xSYSqhTzbBoBiv5j8T7cF3U4FSTv6K30s1ZpB4At4l5VxSnQo8TkL
# yEasADhC38kteSN/J+hXpc1N2O6GxqjrV7XMgIDodH3nAidT0Zwhc0TFAkcQa6Ln
# AFMUpP4XuTPZ/3hsyKGCA3kwggJhAgEBMIHjoYG5pIG2MIGzMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMQ0wCwYDVQQLEwRNT1BSMScwJQYDVQQL
# Ex5uQ2lwaGVyIERTRSBFU046N0QyRS0zNzgyLUIwRjcxJTAjBgNVBAMTHE1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiJQoBATAJBgUrDgMCGgUAAxUA3h07vRT2
# 3FAz5tE3SH05k+CTdy+ggcIwgb+kgbwwgbkxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xDTALBgNVBAsTBE1PUFIxJzAlBgNVBAsTHm5DaXBoZXIg
# TlRTIEVTTjo1N0Y2LUMxRTAtNTU0QzErMCkGA1UEAxMiTWljcm9zb2Z0IFRpbWUg
# U291cmNlIE1hc3RlciBDbG9jazANBgkqhkiG9w0BAQUFAAIFANoKCx0wIhgPMjAx
# NTEyMDMwMDI4MTNaGA8yMDE1MTIwNDAwMjgxM1owdzA9BgorBgEEAYRZCgQBMS8w
# LTAKAgUA2goLHQIBADAKAgEAAgIJbwIB/zAHAgEAAgIYEDAKAgUA2gtcnQIBADA2
# BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMBoAowCAIBAAIDFuNgoQowCAIB
# AAIDB6EgMA0GCSqGSIb3DQEBBQUAA4IBAQBOSwTB8sO/hE2s38Ak5EesPekoYIgp
# QR0LvfrUJ0J5fwu9byooqhJ3IPPVtgtMTN6Bm8j9R+HWq9xeVQyqk5DHXu4B3+yZ
# e/tkGJ+1XgMZZGcReqv1hVKnXGNVzCP9PZ5V0oI0eC6puo/3shWCEoFX02k7JJmY
# YHJ5B+92Lb9xnpI2VsTFCRQI795h+8n9MS4h6mPp6uYtm9bGraqAhH6ERHoDsA7S
# +kY5Hy5TIckjD2re0RtVmnzBVEHXU0gh22b8oUwlPdIGJ4SzJQorcNfCKso62f09
# M3trf1VxNQaH6tcQB1zc+hlHletFfGs1asWdzYB7Z5CEpqjzVprqleccMYIC9TCC
# AvECAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAB2thDh
# fIcjPCIAAAAAAHYwDQYJYIZIAWUDBAIBBQCgggEyMBoGCSqGSIb3DQEJAzENBgsq
# hkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgVBbtAyRKDTt4N4qpC2sdwdCV9v6O
# lPUVU8Cyhhjs4PwwgeIGCyqGSIb3DQEJEAIMMYHSMIHPMIHMMIGxBBTeHTu9FPbc
# UDPm0TdIfTmT4JN3LzCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAy
# MDEwAhMzAAAAdrYQ4XyHIzwiAAAAAAB2MBYEFEFVAzTRPFfZ+nLMx5z1ULFaPy3O
# MA0GCSqGSIb3DQEBCwUABIIBADDxHLcNYxGUmix9kQRzNTshIfaJiW28nuQ2QKzj
# XHVwjD3EpgMsdcqyud+Qwxv/Z55nkA3b0o0bRzhGYx0NgSEZvp+32h/ItetTWj6L
# nODEqj8sOqqxFx6SGkbsRc40dsOUyQlFOr7O/Y1isHV3mtpH/llEgODN7u8u8nBY
# pUF18uTf8QWs3lv+lztj+drbODymFtGGl590jy3UWHkfEnJ5WCTAq0Efst94T1TQ
# 18F+iduv01Vu0M7ZwKAR1zeFjZYyhnvxc5X/z5B0UKkCiOjjX7UoGXcDpOjMQGVc
# qMzkEBFlsyuqIOhPkptCEQuWyEZTVEKy9T/mzHeZk9uF2vM=
# SIG # End signature block
