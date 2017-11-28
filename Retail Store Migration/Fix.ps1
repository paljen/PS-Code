
#@{UserPrincipalName=US302039B1@ecco.com; PrimarySmtpAddress=outlet-carlsbad@ecco.com; Database=DB03; ArchiveDatabase=ARC03; ExchangeGuid=008074f1-4163-4ba6-bf31-0b8ced43b244; ArchiveGuid=0224eda3-5c83-4278-97b7-6c79d61b47b0}
#@{UserPrincipalName=US302049B1@ecco.com; PrimarySmtpAddress=outlet-orange@ecco.com; Database=DB02; ArchiveDatabase=ARC04; ExchangeGuid=2a152c92-7b8f-4f0b-bf97-f3aea06dc6d0; ArchiveGuid=c18e6148-59ad-4248-9a3c-f721fa4aed2a}
#@{UserPrincipalName=US301043B1@ecco.com; PrimarySmtpAddress=store-fashionshow@ecco.com; Database=DB01; ArchiveDatabase=ARC04; ExchangeGuid=1f659b79-178b-45bd-9673-a9fd604a4cb6; ArchiveGuid=5fe65ea0-aa27-417e-b592-c15bf710c7c8}
#@{UserPrincipalName=US301049B1@ecco.com; PrimarySmtpAddress=store-sfgrantave@ecco.com; Database=DB01; ArchiveDatabase=ARC01; ExchangeGuid=14ad983e-440e-40b5-9484-a76dc542b61b; ArchiveGuid=f10a6d16-6cd6-4400-ac87-0ac777eebbc0}
#@{UserPrincipalName=US301059B1@ecco.com; PrimarySmtpAddress=store-laplaza@ecco.com; Database=DB04; ArchiveDatabase=ARC04; ExchangeGuid=5149e9d7-331a-4c00-96c9-b46e5ab0969d; ArchiveGuid=f83408b6-0618-44a2-9243-db0889ff571d}
#@{UserPrincipalName=US301023B1@ecco.com; PrimarySmtpAddress=store-dallas@ecco.com; Database=DB01; ArchiveDatabase=ARC04; ExchangeGuid=70aa3b03-f1ca-421b-9dce-ef183251adf6; ArchiveGuid=1036629d-9f0f-4a29-8436-10e68ff654a8}
#@{UserPrincipalName=US301052B1@ecco.com; PrimarySmtpAddress=store-ardenfair@ecco.com; Database=DB02; ArchiveDatabase=ARC04; ExchangeGuid=08190156-523f-4cd0-93c0-a8b6f43b170e; ArchiveGuid=ce2d7eee-3f3b-4dde-8a43-f621963dadde}

#@{UserPrincipalName=US301046B1@ecco.com; PrimarySmtpAddress=store-sfcentre@ecco.com; Database=DB01; ArchiveDatabase=ARC04; ExchangeGuid=c4e725e6-4318-413e-afd1-74e0dc8dd62d; ArchiveGuid=fbf5fedb-2abf-4e8d-8a2c-a8cf89c7f1a8}
#@{UserPrincipalName=US301058B1@ecco.com; PrimarySmtpAddress=store-broadwayplaza@ecco.com; Database=DB02; ArchiveDatabase=ARC02; ExchangeGuid=9ce5d08f-b16c-4e99-a377-d3a5dfc9d459; ArchiveGuid=34e3907b-5ab5-45d6-8a42-8f0f31ac157f}
#@{UserPrincipalName=US301063B1@ecco.com; PrimarySmtpAddress=store-breamall@ecco.com; Database=DB02; ArchiveDatabase=ARC02; ExchangeGuid=63038059-97a4-4653-8b1e-8c24dbdb9f59; ArchiveGuid=7fae7cfc-892e-4c57-9cd6-a01f837b4e47}
#@{UserPrincipalName=US302029B1@ecco.com; PrimarySmtpAddress=outlet-sanmarcos@ecco.com; Database=DB03; ArchiveDatabase=ARC03; ExchangeGuid=57a09268-458c-4e96-91fb-e201414126f6; ArchiveGuid=bc1a5846-a657-4473-94b1-917690477197}

@{UserPrincipalName=US301064B1@ecco.com; PrimarySmtpAddress=store-pentagon@ecco.com; Database=DB01; ArchiveDatabase=ARC01; ExchangeGuid=d96d5c1d-2bff-4349-812e-aafdfee6264a; ArchiveGuid=39de2fd4-5f7e-4787-a8ab-6e38aa2c9cd1}


$user = "USStore1077"

$recpt = Get-Recipient -Identity $user -ErrorAction Ignore

#New-MailboxRestoreRequest -SourceStoreMailbox "bc1a5846-a657-4473-94b1-917690477197" -SourceDatabase "ARC03" -TargetMailbox $(($recpt.GUID).ToString()) -TargetIsArchive -AllowLegacyDNMismatch -DomainController "dkhqdc02.prd.eccocorp.net" | Out-Null

Set-Mailbox -Identity USStore1077 -EmailAddressPolicyEnabled $false -PrimarySmtpAddress "store-pentagon@ecco.com" -RetentionPolicy "ECCO Default Retention Policy" -DomainController "dkhqdc02.prd.eccocorp.net" | Out-Null