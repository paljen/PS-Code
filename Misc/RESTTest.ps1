# Eg. User name="admin", Password="admin" for this code sample.
$user = "service-rest-request"
$pass = "JOhnINBrede12"

# Build auth header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user, $pass)))

# Set proper headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add('Authorization',('Basic {0}' -f $base64AuthInfo))
$headers.Add('Accept','application/json')


# Specify endpoint uri
$uri = "https://eccodev.service-now.com/api/now/table/sc_req_item?sysparm_limit=1&sys_id=9abcf0a6db98360096e8f7461d9619a4"

# Specify HTTP method
$method = "get"


# Send HTTP request
$response = Invoke-WebRequest -Headers $headers -Method $method -Uri $uri

# Print response
$response.RawContent