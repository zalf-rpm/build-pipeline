# requires powershell version 6 or later
Remove-Service -Name "email-attachment-service"

# if above doesn't work or the process is still running, try this:
sc.exe delete "email-attachment-service"

# if your service windows is running and the process still shows up in the list,
# restart your service window