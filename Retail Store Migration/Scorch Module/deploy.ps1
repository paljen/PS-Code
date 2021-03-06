$basePath = "C:\Program Files\SCOrchDev\Modules"
if(-not(Test-Path $basePath))
{
	New-Item -ItemType directory -Path $basePath
}

Copy-Item -Recurse -Force -Confirm:$False -Path ".\scorch" -Destination $basePath
$machinePSModulePath = [Environment]::GetEnvironmentVariable('PSModulePath','Machine')
if (@($machinePSModulePath -split ';') -notcontains $basePath)
{
	# Add the module base path to the machine environment variable
	$machinePSModulePath += ";${basePath}"
	# Add the module base path to the process environment variable
	$env:PSModulePath += ";${basePath}"
	# Update the machine environment variable value on the local computer
	[Environment]::SetEnvironmentVariable('PSModulePath', $machinePSModulePath, 'Machine')
}
Import-Module -Name Scorch -PassThru

# SIG # Begin signature block
# MIIEMwYJKoZIhvcNAQcCoIIEJDCCBCACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUaakkpdsVtMLCcKywUsYdTddH
# Uu2gggI9MIICOTCCAaagAwIBAgIQseGrl29S06FMeE0VHeRmBjAJBgUrDgMCHQUA
# MCwxKjAoBgNVBAMTIVBvd2VyU2hlbGwgTG9jYWwgQ2VydGlmaWNhdGUgUm9vdDAe
# Fw0xNTA4MTQwODU4MjRaFw0zOTEyMzEyMzU5NTlaMBoxGDAWBgNVBAMTD1Bvd2Vy
# U2hlbGwgVXNlcjCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAy37vPNrPcBQB
# jGVLpq02rlaKRKH3BEg0SZN1nRUX0dTgcvOVffySRZotrwtgDnsEjVxP+2qxYsJF
# +C0W+9AQ1JHXgneQ78ZVPXCQvbcPsyxZOOHl1TCOYx9GgrtNHvQRws0mV2VrOdEt
# M3fUy3xGdS386Cah5WmwPoUim7Y1Zp0CAwEAAaN2MHQwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMwXQYDVR0BBFYwVIAQCo2DRLKTpRLU0HO2vhsIE6EuMCwxKjAoBgNVBAMT
# IVBvd2VyU2hlbGwgTG9jYWwgQ2VydGlmaWNhdGUgUm9vdIIQdv41EPm1r5JFpDY7
# oE+4nDAJBgUrDgMCHQUAA4GBACenqfn0Bo9qeukrKPt1hfzwttJo9UTS5nDK8s1J
# /v1a4NgzQPE+8ZqcGusDW+uNENfoFek6pak+Cabpl7aG8pYrDuEIquOgkuBnRdxU
# DG2jBSTR3yo+5o/RM33XOyZsxqYJukREapQDsPp3NU8yK95/o4dcMX30oZEjj26b
# kIeAMYIBYDCCAVwCAQEwQDAsMSowKAYDVQQDEyFQb3dlclNoZWxsIExvY2FsIENl
# cnRpZmljYXRlIFJvb3QCELHhq5dvUtOhTHhNFR3kZgYwCQYFKw4DAhoFAKB4MBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYE
# FGmPfkBcLhQm0Q/61getGfMwGcnrMA0GCSqGSIb3DQEBAQUABIGAgVnMCK3jpisM
# i86Stk4QsZTg0+yDDrk6/K3rVD1gAsYbk7qNlOKre8haBCPUxrviYzbu1BS2RAlc
# zlRIgtLPo08ZZ7cL2sAnRlF0M8GVN3jluzN1x3qsYh6yQI6kMaIc12u3SJesAgK0
# taDh464NFPUmc4e8MWJX0c5ZYlqf9ig=
# SIG # End signature block
