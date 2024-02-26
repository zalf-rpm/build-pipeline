#!/bin/bash
#/ usage: start ?user? ?version?
[[ $# < 2 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
VERSION=$2

WORKDIR=/beegfs/${USER}/R_playground${VERSION}/.rundeck
TRANS=${WORKDIR}/r_trans.yml
mkdir -p -m 700 $WORKDIR

# remove setup file if it exists from previous run
if [ -f ${TRANS} ] ; then
    rm ${TRANS}
fi 
