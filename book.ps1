


function dbcheck
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
    [String]$UpdateSameLicense)
    
    $PSCmdlet.MyInvocation.BoundParameters.BoundPositionally

    write-debug "test"
    #write-error "stopping"

    write-host "that error was non terminating"
    Write-Output $bla
}

try
{
    $ok = dbcheck -ErrorAction stop
}
catch
{
    $_.exception.message
}




#help write-error