# this is a demo script to show how to upload files to the HPC with R
# using ssh with a key file for authentication 

# load the ssh package, install it if not already installed
if (!requireNamespace("ssh", quietly = TRUE)) {
  install.packages("ssh")
}
library(ssh)

# creata a session to the HPC, replace with your own username and path to your key file
session <- ssh_connect("user@mycluster.de")

# upload a file to the HPC, replace with your own local file path and remote destination path
scp_upload(session, "C:\\Users\\myuser\\Desktop\\example.txt", to = "/beegfs/user/remote/")

# repeat the upload for another file..

# disconnect the session when done
ssh_disconnect(session)