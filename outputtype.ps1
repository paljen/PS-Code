
Function OutputType
{
    [CmdletBinding()]
    [OutputType([Microsoft.ActiveDirectory.Management.ADUser])]

    param(
        [Parameter(Mandatory=$true)]
        [String]$Username
    )

    $user = Get-aduser $Username

    $props = @{'Name'= @{'Connect'=$($user.name)}}
    $obj = New-Object -TypeName PSObject -Property $props
    write-output $obj
}

(OutputType -Username pje).Name | gm









