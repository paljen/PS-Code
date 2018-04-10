function Get-AMRestAPIAuthorizationCodeGrant {

    [CmdletBinding()]
    [OutputType([System.String])]
   
    param (
        
        [Parameter(Mandatory=$true)]
        [String]$Tenant,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory=$true)]
        [String]$ApplicationId,

        [Parameter(Mandatory=$true)]
        [System.Uri]$RedirectUri,

        [Parameter(Mandatory=$true)]
        [String]$ResourceUri,

        [Parameter(Mandatory=$true)]
        [String]$Authority

    )

    try {

        Import-Module AzureRm.Profile
        
        $authContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new("$Authority/$tenant")

        if($Credential) {
        
            $userCred = [Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential]::new($credential.UserName,$credential.Password)
            $authToken = $authContext.AcquireToken($ResourceUri, $ApplicationId, $userCred)
        }
        else {
            
            $authToken = $authContext.AcquireToken($ResourceUri, $ApplicationId, $RedirectUri, "Always")
        }

        $authToken.CreateAuthorizationHeader()
    }

    catch {

        Throw
    }

    finally {

        if(Get-Module AzureRm.Profile) {
            Remove-Module AzureRm.Profile -ErrorAction SilentlyContinue
        }
    }
} 
