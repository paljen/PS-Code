
$ClientID = "57b202a3-af22-412e-818a-37c7710d7163"
$client_Secret = "Cvz+o7ssVm3qD7+u/yQyln4npzLtFlWf+I2bX2co+xA="

# If ClientId or Client_Secret has special characters, UrlEncode before sending request
$clientIDEncoded = [System.Web.HttpUtility]::UrlEncode($ClientID)
$client_SecretEncoded = [System.Web.HttpUtility]::UrlEncode($client_Secret)

#Define uri for Azure Data Market
$Uri = "https://login.microsoftonline.com/06152121-b4c5-4544-abf5-9268e75db448/oauth2/token"

#Define the body of the request

$Body = "grant_type=client_credentials&client_id=$clientIDEncoded&client_secret=$client_SecretEncoded&resource:https://management.azure.com/"
# $Body = "grant_type=client_credentials&client_id=$clientIDEncoded&client_secret=$client_SecretEncoded&scope=http://api.microsofttranslator.com"

#Define the content type for the request
$ContentType = "application/json"

#Invoke REST method.  This handles the deserialization of the JSON result.  Less effort than invoke-webrequest
$admAuth=Invoke-RestMethod -Uri $Uri -Body $Body -Method Post

#Construct the header value with the access_token just recieved
$HeaderValue = "Bearer " + $admauth.access_token
#endregion

$guid = [System.Guid]::NewGuid()

$runbook = 'Get-ADLAPSPassword'
$computer = "DK5235"

$subscription_id = 'd656c404-566b-4db7-b6ac-495dd728b201'
$resource_group = 'RG-Automation'
$account_name = 'AzAutomationWestEurope01'

$url = "https://management.azure.com/subscriptions/$($subscription_id)/resourceGroups/$($resource_group)/providers/Microsoft.Automation/automationAccounts/$($account_name)/jobs/$($guid)?api-version=2015-10-31"

#$body = { 'properties' : { 'runbook' : {  'name' : runbook  }, 'parameters' : {  'computer' : computer }, "runOn": "ECCO-DKHQ"}  }

$body2 = @{'properties'=@{'runbook'=@{'name'=$runbook};'parameters'=@{'computer'=$computer};'runOn'="ECCO-DKHQ"}} 
$body2 = $body2 | ConvertTo-Json

#$result = Invoke-RestMethod -Uri $uri -Headers @{Authorization = $HeaderValue} 
Invoke-WebRequest -Uri $uri -Headers @{'Authorization' = $HeaderValue} -Body $body2 -Method Post -ContentType $ContentType

$result.string.'#text'
