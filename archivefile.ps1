$file = get-item C:\Temp\*.*

#$file | select * -First 1

$file | foreach { 

    if($_.Length /1MB -gt 2.0 -and $_.LastWriteTime -lt (Get-Date).AddDays(-14)){
        $_.fullName
        Move-Item $_.FullName -Destination c:\temp\archive
    }
}

