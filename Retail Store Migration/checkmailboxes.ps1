
"US301055B1","US302006B1","US302045B1","US301067B1","US301051B1","US302044B1","US301052B1" | % {
    $mb = get-mailbox $_ 
    $mb | Get-MailboxStatistics | select @{l='PrimarySMTPAddress';e={$mb.PrimarySmtpAddress}}, displayname,itemcount,Total*
}