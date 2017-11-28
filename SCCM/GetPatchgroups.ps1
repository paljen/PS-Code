
get-adgroup -Filter {(Name -like "*Patch-prd*") -or (Name -like "*Patch-Inf*")} -SearchBase "ou=patch management,ou=centrally managed,ou=groups,dc=prd,dc=eccocorp,dc=net" | foreach {

    $_ | select @{l='Name';e={$_.name}},@{l='Count';e={ (get-adgroupmember $_).count}}

} | sort name | ft -AutoSize