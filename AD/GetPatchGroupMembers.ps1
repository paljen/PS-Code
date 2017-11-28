$groups = (get-adgroup -Filter * -SearchBase "ou=patch management,ou=Centrally managed,ou=groups,dc=prd,dc=eccocorp,dc=net").distinguishedname

#Measure-Command {$groups | foreach {write-host $_}}

#Measure-Command {foreach ($g in $groups){write-host $g}}

foreach ($g in $groups)
{
    write-host $g

    #Get-ADGroupMember -Identity $g
   Get-ADGroupMember -Identity $g | foreach {
    write-host "`t $($_)"
   }
}

(Get-ADComputer -Filter {OperatingSystem -Like '*Server*'}).name | out-file 'C:\Powershell\SCCM Server compare\AD.txt'

diff -ReferenceObject (get-content 'C:\Powershell\SCCM Server compare\AD.txt') -DifferenceObject (Get-Content 'C:\Powershell\SCCM Server compare\SCCM.txt')
