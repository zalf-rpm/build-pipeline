#!/bin/bash
cd ${HERMES_HOME} 
ls -al

if [ ${USERID} != 0 ] && [ ${GROUPID} != 0 ] ; then 
addgroup --gid ${GROUPID} mygroup
adduser --gecos "" --disabled-password --uid ${USERID} --ingroup mygroup myuser 
fi 
sudo -H -u myuser xvfb-run -a wine $@