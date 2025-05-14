New-Service -Name "EmailAttachmentDownload" -Description "MAS service to download email attachments automatically" -BinaryPathName email-attachment-service.exe 

# check if the service is installed
Get-CimInstance -ClassName Win32_Service -Filter "Name='EmailAttachmentDownload'"

# start the service
Start-Service -Name "EmailAttachmentDownload"