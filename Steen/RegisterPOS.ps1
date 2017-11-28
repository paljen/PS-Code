
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
$key = "89 171 118 60 58 254 218 61 140 93 2 109 84 102 189 13 22 85 88 237 101 180 37 174 207 53 53 231 70 220 170 105"
$psw = "76492d1116743f0423413b16050a5345MgB8AHgAZABZADgAMgBvAHEANAA2AFgAWABUAG8AdwBhADQAVwBzAFEAUgBUAFEAPQA9AHwAMQBkAGUA`
        NQBhAGYANAA1ADcAMwA2ADAAMAA2ADMAYgA3AGQAMwA5AGUAZgBlAGEAYwA0AGUAMQA2AGUAZABjAGMAYwAxAGEAZgBlAGYAMAA1ADMAMQAxAGIA`
        MgA5ADIAZgA0ADgAZABmADMAZAA3AGYANgA0AGEAYwAxADEANQA="

$pswSecure = ConvertTo-SecureString -String $psw -Key ([Byte[]]$key.Split(" "))
$pswSecure.MakeReadOnly()

$cred = New-Object system.Management.Automation.PSCredential("asp_user", $pswSecure)

try{    
    $query = "SELECT * FROM [GK_GBR].[dbo].[DNS_View]"
    
    [System.Collections.ArrayList]$records = Get-DBRecordset -ConnectionString $connString -Credentials $cred -Query $query |select -First 20
    $records.RemoveAt(0)

    $session = New-PSSession -ComputerName $dc -Authentication Kerberos

    $DNSRecords = Invoke-Command -Session $session -ScriptBlock {

        Import-Module DNSServer

        $out = @()

        $forwardZone = 'prd.eccocorp.net'
        $reverseZone = '172.in-addr.arpa'

        $using:records | Foreach {

            try{
                $current = @{'Host'=$_.Host;'KnownIP'=$_.KnownIP}

                $oRecord = Get-DnsServerResourceRecord -Name $($_.Host) -ZoneName $forwardZone -RRType "A" -ErrorAction Stop
                $nRecord = $oRecord.Clone()

                # reverse IP
                $reverseIpArray = [System.Collections.ArrayList] @($($nRecord.RecordData.IPv4Address.IPAddressToString).Split("."))                    
                $reverseIpArray.RemoveAt(0)
                $reverseIpArray.Reverse()
                $ptrName = $($reverseIpArray -join ".")
                                 
                [System.Net.IPAddress]$newip = [System.Net.IPAddress]($_.KnownIP)
                $nRecord.RecordData.IPv4Address = $newip
                
                $setDns += "$((Set-DnsServerResourceRecord -NewInputObject $nRecord -OldInputObject $oRecord -ZoneName $forwardZone -PassThru -ErrorAction SilentlyContinue).DistinguishedName)`n"
                $addPtr += "$((Add-DnsServerResourceRecordPtr -Name $ptrName -ZoneName $reverseZone -AllowUpdateAny -PtrDomainName "$($_.Host).$forwardZone" -PassThru -ErrorAction SilentlyContinue).DistinguishedName)`n"
            }
            catch [Microsoft.Management.Infrastructure.CimException] 
            {
                try
                {
                    $addDns += "$((Add-DNSServerResourceRecordA -ZoneName $forwardZone -Name $current.Host -IPv4Address $current.KnownIP -CreatePtr -AllowUpdateAny -PassThru -ErrorAction Stop).DistinguishedName)`n"
                }
                catch
                {
                    $err += "Bøf"
                    $err += $error[0].Exception
                }
            }
            catch 
            {
                $err += $error[0].Exception
            }
        }

        @{'AddedARecords'=$adddns;
          'UpdatedARecords'=$setdns;
          'UpdatedPtrRecords'=$addPtr;
          'Errors'=$err}
    }
}
catch
{
    Write-Error ($error[0].Exception) -ErrorAction SilentlyContinue
}

finally{
    $obj = New-Object -TypeName PSObject -Property $DNSRecords
    Write-Output $obj
}
