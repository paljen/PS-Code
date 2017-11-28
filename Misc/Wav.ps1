






[byte[]]$c = Get-content -Path "C:\temp\test.wav" -Encoding Byte -ReadCount 0



Import-UMPrompt -UMDialPlan “PL UM Dial Plan” -PromptFileName "test.wav" -PromptFileData $c