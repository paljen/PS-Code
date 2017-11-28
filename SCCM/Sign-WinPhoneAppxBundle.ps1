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
#&"$MakeAppxPath" unpack /l /p "$InputAppx" /d "$appxTempFolder"
&"$MakeAppxPath" unbundle /v /p "$InputAppx" /d "$appxTempFolder"

if(!$?)
{
    Throw "Failed to unpack the appx file."
}

# Edit AppxManifest.xml.
$appxManifestFile = [IO.Path]::Combine($appxTempFolder, "AppxMetadata\AppxBundleManifest.xml")
$appxManifest = [xml](get-content $appxManifestFile)

$appxManifest.Package.Identity.Publisher = $PublisherId
Write-Verbose "Publisher is set to: $PublisherId"

$appxManifest.Package.PhoneIdentity.PhonePublisherId = [string]$PhonePublisherId
Write-Verbose "PhonePublisherId is set to: $PhonePublisherId"

Write-Verbose 'Saving changes to AppxManifest.xml'
$appxManifest.Save($appxManifestFile)

# Create the final appx file
#&"$MakeAppxPath" pack /l /d "$appxTempFolder" /p "$OutputAppx" /o
&"$MakeAppxPath" bundle /v /d "$appxTempFolder" /p "$OutputAppx" /o
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

