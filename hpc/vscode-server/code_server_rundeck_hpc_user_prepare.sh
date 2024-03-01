#!/bin/bash -x
#/ usage: start ?user? ?version?
[[ $# < 2 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
VERSION=$2
SERVER_PASS=@option.PassW@

WORKDIR=/beegfs/${USER}/code_server_playground${VERSION}/.config/code-server
CONFIG=${WORKDIR}/config.yaml

mkdir -p -m 700 $WORKDIR
# make sure the directory can only be accessed by the user
# change permissions
chmod 700 $WORKDIR

# create password hash
HASH=$(echo -n ${SERVER_PASS} | openssl dgst -sha256 | cut -d' ' -f2)

# create config file
if [ ! -f ${CONFIG} ] ; then

cat <<EOF > ${CONFIG}
bind-addr: 0.0.0.0:8443
auth: password
hashed-password: $HASH
cert: false
EOF
elif [ ! -z "$HASH" ] ; then
# update password
sed -i "s/hashed-password: .*/hashed-password: $HASH/g" ${CONFIG}
fi 

