#!/bin/bash -x
#/ usage: start ?user? ?version?
[[ $# < 2 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
VERSION=$2

WORKDIR=/beegfs/${USER}/jupyter_playground${VERSION}/.rundeck
TRANS=${WORKDIR}/jupyter_trans.yml
mkdir -p -m 700 $WORKDIR

# remove setup file if it exists from previous run
if [ -f ${TRANS} ] ; then
    rm ${TRANS}
fi 
