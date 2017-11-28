# Run DP Usage schedule
$servers = get-content c:\scripts\Servers.txt

foreach($server in $servers){
  "$server $(schtasks /run /TN "Microsoft\Configuration Manager\Content Usage" /s $server)" 
}

 
