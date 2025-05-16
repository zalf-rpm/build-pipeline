


# Email Attachment Service
this is a Windows service that downloads email attachments from a specified email account and saves them to a specified folder.
use the config.yml file to configure the service.

install the service using the following script:
powershell script
install_service.ps1

Note: to install a service, you need to run the installation as an administrator.
On some machines, the execution of powershell scripts is disabled by default. 
If that is the case, just copy the content of the script and paste it in a powershell window to run it.


How to: Install and uninstall Windows services
https://learn.microsoft.com/de-de/dotnet/framework/windows-services/how-to-install-and-uninstall-services

About New-Service
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-service?view=powershell-7.5

Note:
you need to use a particular service name in order to run a particular service (and note that the name is case-sensitive). This is because the service, on startup, needs to register with the Service Control Manager to receive start/stop notifications and send status updates, using its service name. If you install the service with a different name, but the executable has no way of knowing this (through a configuration setting or whatnot), this registration will fail and the service can't start (to the operating system, it will look as if the service is failing to respond).