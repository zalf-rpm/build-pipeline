#!/bin/bash

if [ ${USERID} != 0 ] && [ ${GROUPID} != 0 ] ; then 
addgroup --gid ${GROUPID} mygroup
adduser --gecos "" --disabled-password --uid ${USERID} --ingroup mygroup myuser 
usermod -aG docker myuser
fi 

sudo -H -u myuser ls -al 
sudo -H -u myuser echo $PATH
sudo -H -u myuser ls -al /go/bin
sudo -H -u myuser /go/bin/$@