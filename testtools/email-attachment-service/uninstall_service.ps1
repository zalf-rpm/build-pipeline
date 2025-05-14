# requires powershell version 6 or later
Remove-Service -Name "EmailAttachmentDownload"

# if above doesn't work or the process is still running, try this:
sc.exe delete "EmailAttachmentDownload"

# if your service windows is running and the process still shows up in the list,
# restart your service window