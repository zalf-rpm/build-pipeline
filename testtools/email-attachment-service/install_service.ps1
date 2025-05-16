

New-Service -Name "email-attachment-service" `
            -Description "MAS service to download email attachments automatically" `
            -BinaryPathName $PWD\email-attachment-service.exe `
            -Credential "NT AUTHORITY\LocalService"

# check if the service is installed
Get-CimInstance -ClassName Win32_Service -Filter "Name='email-attachment-service'"

# start the service
Start-Service -Name "email-attachment-service"

sc.exe create "email-attachment-service" binPath= "$PWD\email-attachment-service.exe" obj= "NT AUTHORITY\LocalService" 