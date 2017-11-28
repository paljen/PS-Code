
function Get-DBRecordSet
{
    [CmdletBinding()]
    [OutputType([System.Data.DataSet])]
    
    param 
    (
        [string]$ConnectionString,
        [string]$Query,
        [PSCredential]$Credentials
    )

    $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection

    $connection.ConnectionString = $connectionString
    $connection.Credential = ([System.Data.SqlClient.SqlCredential]::new($cred.UserName,$cred.Password))

    $command = $connection.CreateCommand()
    $command.CommandText = $query


    $adapter = New-Object -TypeName System.Data.SqlClient.SqlDataAdapter $command

    $dataset = New-Object -TypeName System.Data.DataSet

    $adapter.Fill($dataset)
    $dataset.Tables[0]

    $connection.close()
}

$dc = "DKHQDC01"
$connString = "server=dkhqsapfmstst01;database=GK_GBR;trusted_connection=True;Integrated Security=False;"

# Credentials
$psw = "76492d1116743f0423413b16050a5345MgB8AHgAZABZADgAMgBvAHEANAA2AFgAWABUAG8AdwBhADQAVwBzAFEAUgBUAFEAPQA9AHwAMQ`
        BkAGUANQBhAGYANAA1ADcAMwA2ADAAMAA2ADMAYgA3AGQAMwA5AGUAZgBlAGEAYwA0AGUAMQA2AGUAZABjAGMAYwAxAGEAZgBlAGYAMAA1`
        ADMAMQAxAGIAMgA5ADIAZgA0ADgAZABmADMAZAA3AGYANgA0AGEAYwAxADEANQA="

$key = "89 171 118 60 58 254 218 61 140 93 2 109 84 102 189 13 22 85 88 237 101 180 37 174 207 53 53 231 70 220 170 105"
$pswSecure = ConvertTo-SecureString -String $psw -Key ([Byte[]]$key.Split(" "))
$pswSecure.MakeReadOnly()
$cred = New-Object system.Management.Automation.PSCredential("asp_user", $pswSecure)

try
{    
    # Query
    $query = "SELECT * FROM [GK_GBR].[dbo].[DNS_View]"
    $records = Get-DBRecordset -ConnectionString $connString -Credentials $cred -Query $query

    # Implicit remoting
    $session = New-PSSession -ComputerName $dc -Authentication Kerberos
    Invoke-Command -Session $session -ScriptBlock {Import-Module DNSServer}    
    Import-PSSession -Session $session -Module DNSServer -AllowClobber

    $forwardZone = 'prd.eccocorp.net'
    $reverseZone = '172.in-addr.arpa'

    foreach ($record in $records)
    {
        try
        {
            # Get current record
            $oRecord = Get-DnsServerResourceRecord -Name $record.Host -ZoneName $forwardZone -RRType "A" -ErrorAction Stop

            $nRecord = $oRecord.Clone()
            
            # Contruct new ip address and assign it to the cloned record      
            [System.Net.IPAddress]$newip = [System.Net.IPAddress]($record.KnownIP)
            $nRecord.RecordData.IPv4Address = $newip

            # Update old record with the new record if IP address has changed, continue on error
            if($oRecord.RecordData.IPv4Address -ne $nRecord.RecordData.IPv4Address){

                # Update record and add to hashtable
                (Set-DnsServerResourceRecord -NewInputObject $nRecord -OldInputObject $oRecord -ZoneName $forwardZone -PassThru -ErrorAction SilentlyContinue).DistinguishedName
            
                # Create updated pointer record, continue on error
                $reverseIpArray = [System.Collections.ArrayList] @(($nRecord.RecordData.IPv4Address.IPAddressToString).Split("."))                    
                $reverseIpArray.RemoveAt(0) # remove first record in the array since this is not used
                $reverseIpArray.Reverse() # reverse all the array elements
                $ptrName = $($reverseIpArray -join ".") # join all elements in the array with . to create a string

                (Add-DnsServerResourceRecordPtr -Name $ptrName -ZoneName $reverseZone -AllowUpdateAny -PtrDomainName "$($record.Host).$forwardZone" -PassThru -ErrorAction SilentlyContinue).DistinguishedName
            }
        }
        catch [System.Management.Automation.RemoteException] 
        {
            try
            {
                (Add-DNSServerResourceRecordA -ZoneName $forwardZone -Name $record.Host -IPv4Address $record.KnownIP -CreatePtr -AllowUpdateAny -PassThru).DistinguishedName
            }
            catch
            {
                $error[0].Exception
            }
        }
        catch 
        {
            $error[0].Exception
        }
    }
}
catch
{
    $error[0].Exception
    
}
