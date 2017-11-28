# Initializing Directory Services
    $rootDSE = [System.DirectoryServices.DirectoryEntry]("LDAP://RootDSE")
    $RootPath = "LDAP://{0}" -f $rootDSE.defaultNamingContext.ToString()
    $root = [System.DirectoryServices.DirectoryEntry]$RootPath
    
    # Create searchfilter and fínd client computer in AD
	$search = [System.DirectoryServices.DirectorySearcher]$root
	$search.Filter = "(&(objectClass=computer)(operatingsystem=*server*))"
	$ComputerADObject = $search.Findall()
            
           