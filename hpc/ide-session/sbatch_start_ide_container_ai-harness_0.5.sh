#!/bin/bash
# Started by rundeck_start_ide_container.sh via sbatch (resources, time, log files are set there).
# Starts an sshd as the user inside a singularity container. VS Code connects to it via ssh.

set -u

# script input
PROJECT_DIR=$1
MOUNT_DATA_SOURCE1=$2 # optional, readonly
MOUNT_DATA_SOURCE2=$3 # optional, readonly
MOUNT_DATA_SOURCE3=$4 # optional, readonly
MOUNT_OUTPUT=$5 # optional, read-write
IMAGE_PATH=$6
LOGIN_HOST=$7
LAUNCH_DIR=$8

# check if project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Project directory $PROJECT_DIR does not exist. Exiting."
    exit 1
fi

# bind mounts, format: src:dest:opts
BINDS="$PROJECT_DIR:$PROJECT_DIR:rw"

add_ro_mount() { # $1 = directory or "none"
    if [ "$1" = "none" ]; then
        echo "No data directory provided, skipping mount."
    elif [ ! -d "$1" ]; then
        echo "Data directory $1 does not exist. Exiting."
        exit 1
    else
        BINDS="$BINDS,$1:$1:ro"
    fi
}
add_ro_mount "$MOUNT_DATA_SOURCE1"
add_ro_mount "$MOUNT_DATA_SOURCE2"
add_ro_mount "$MOUNT_DATA_SOURCE3"

if [ "$MOUNT_OUTPUT" = "none" ]; then
    echo "No output data directory provided, skipping mount."
else
    # create it if it does not exist
    if [ ! -d "$MOUNT_OUTPUT" ]; then
        mkdir -p "$MOUNT_OUTPUT" || { echo "Output data directory $MOUNT_OUTPUT does not exist and cannot be created. Exiting."; exit 1; }
    fi
    BINDS="$BINDS,$MOUNT_OUTPUT:$MOUNT_OUTPUT:rw"
fi

NV=""
if [ "$SLURM_JOB_PARTITION" = "gpu" ]; then
    NV="--nv"
fi

# the "home" of the container: persistent, holds authorized_keys, sshd host key and the vscode-server installation
HOMEDIR=/beegfs/$USER/ide
mkdir -p "$HOMEDIR"
SSH_FOLDER=$HOMEDIR/.ssh
mkdir -p "$SSH_FOLDER"
# make sure the directories can only be accessed by the user (sshd StrictModes requires this)
chmod 700 "$SSH_FOLDER" "$HOMEDIR"

# authorized_keys: the user logs in with the same key pair as on the cluster.
# If there is no key yet, take the keys from the cluster home directory.
AUTH_KEYS=$SSH_FOLDER/authorized_keys
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
if [ ! -s "$AUTH_KEYS" ] && [ -s "/home/$USER/.ssh/authorized_keys" ]; then
    cp "/home/$USER/.ssh/authorized_keys" "$AUTH_KEYS"
    echo "authorized_keys initialized from /home/$USER/.ssh/authorized_keys"
fi
if [ ! -s "$AUTH_KEYS" ]; then
    echo "No public key in $AUTH_KEYS - ssh login will not be possible." >&2
fi

# ssh sessions start in the container home. Let interactive shells (ssh, vscode terminals) change into the
# project directory of the current session; sshd passes it as IDE_PROJECT_DIR (see SetEnv in sshd_config).
# The container home is shared by all sessions of the user, so the snippet is only added once.
if ! grep -qs '# >>> ide-session >>>' "$HOMEDIR/.bashrc"; then
    cat <<'SNIPPET' >> "$HOMEDIR/.bashrc"

# >>> ide-session >>>
if [ -n "${IDE_PROJECT_DIR:-}" ] && [ "$PWD" = "$HOME" ] && [ -d "$IDE_PROJECT_DIR" ]; then
    cd "$IDE_PROJECT_DIR"
fi
# <<< ide-session <<<
SNIPPET
fi
# login shells read .bash_profile, make sure it loads .bashrc
if [ ! -e "$HOMEDIR/.bash_profile" ]; then
    echo '[ -f ~/.bashrc ] && . ~/.bashrc' > "$HOMEDIR/.bash_profile"
fi

# workdir that is cleaned up after the session
WORKDIR=/scratch/${USER}_ide_${SLURM_JOB_ID}
LAUNCH_FILE=$LAUNCH_DIR/${SLURM_JOB_ID}.rundeck
# function to clean up work directory on exit
cleanup() {
    echo "cleanup: removing $WORKDIR"
    # read-only directories created by tools in the container would make rm fail
    chmod -R u+rwX "$WORKDIR" 2>&1
    rm -rf "$WORKDIR" 2>&1
    rm -f "$LAUNCH_FILE" "$LAUNCH_FILE.tmp"
    if [ -e "$WORKDIR" ]; then
        echo "cleanup: WARNING $WORKDIR could not be removed completely" >&2
    else
        echo "Workdir directory removed."
    fi
}
# trap EXIT signal to ensure cleanup is called on job completion
trap cleanup EXIT
# scancel / time limit send SIGTERM (followed by SIGKILL after KillWait, no cleanup is possible then):
# stop the container immediately and exit, so that the EXIT trap runs.
# The container runs in the background (see below), because bash handles traps only after
# a foreground command has finished, but at once while it is in "wait".
SING_PID=""
on_signal() {
    echo "signal received, stopping container"
    if [ -n "$SING_PID" ]; then
        kill -TERM "$SING_PID" 2>/dev/null
        wait "$SING_PID" 2>/dev/null
    fi
    exit 143
}
trap on_signal TERM INT HUP

mkdir -p "$WORKDIR/tmp" "$WORKDIR/vartmp" "$WORKDIR/run"
chmod 700 "$WORKDIR"
chmod 1777 "$WORKDIR/tmp" "$WORKDIR/vartmp"
chmod 755 "$WORKDIR/run"
# /tmp, /var/tmp and /run (sockets, pid/lock files) of the container live on node-local scratch and vanish with the session
BINDS="$BINDS,$WORKDIR/tmp:/tmp,$WORKDIR/vartmp:/var/tmp,$WORKDIR/run:/run"

# --- sshd setup -------------------------------------------------------------
# sshd runs as the normal user (no root): it can only log in this one user, and every
# session it spawns lives inside the container (own PID namespace -> killed with the container).

# host key: generated once per user and kept, so the fingerprint stays the same for all sessions
HOSTKEY_DIR=$HOMEDIR/.sshd_hostkey
HOSTKEY=$HOSTKEY_DIR/ssh_host_ed25519_key
mkdir -p "$HOSTKEY_DIR"
chmod 700 "$HOSTKEY_DIR"
if [ ! -s "$HOSTKEY" ]; then
    # generate in workdir and move atomically (two sessions of one user may start at the same time)
    singularity exec --containall -B "$WORKDIR" "$IMAGE_PATH" \
        ssh-keygen -q -t ed25519 -N "" -C "hpc-ide-$USER" -f "$WORKDIR/hostkey" || { echo "Could not create host key" >&2; exit 1; }
    mv -n "$WORKDIR/hostkey" "$HOSTKEY"
    mv -n "$WORKDIR/hostkey.pub" "$HOSTKEY.pub"
fi

# get a free port on the node for ssh (python3 or python, whatever is available)
PYTHON=$(command -v python3 || command -v python || true)
if [ -n "$PYTHON" ]; then
    CONTAINER_SSH_PORT=$($PYTHON -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
else
    CONTAINER_SSH_PORT=$((20000 + RANDOM % 20000))
fi
# check if free port was found
if [ -z "$CONTAINER_SSH_PORT" ] ; then
   echo "Error: Could not assign free port on node for container" >&2
   exit 1
fi
NODE=$(hostname -s)
echo "Free port on allocated $NODE: $CONTAINER_SSH_PORT"

# sshd config (paths are the same inside and outside, because HOMEDIR is the container home)
SSHD_CONFIG=$WORKDIR/sshd_config
cat <<EOF > "$SSHD_CONFIG"
Port $CONTAINER_SSH_PORT
ListenAddress 0.0.0.0
HostKey $HOSTKEY
PidFile none
AuthorizedKeysFile $AUTH_KEYS
AllowUsers $USER
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin no
UsePAM no
StrictModes yes
# VS Code remote needs tcp forwarding (it tunnels to its server process)
AllowTcpForwarding yes
X11Forwarding no
PrintMotd no
ClientAliveInterval 60
ClientAliveCountMax 5
Subsystem sftp internal-sftp
# start directory for shells, evaluated in ~/.bashrc of the container home
SetEnv IDE_PROJECT_DIR=$PROJECT_DIR
EOF

END_TIME=$(squeue -h -j "$SLURM_JOB_ID" -o %e 2>/dev/null || echo "unknown")

# write the instructions for the user, but only after sshd really accepts connections.
# Runs in background, the file is moved into place atomically (rundeck polls for it).
(
    for i in $(seq 1 60); do
        # only open the connection, send nothing (sending data makes sshd log "invalid format")
        if (: > "/dev/tcp/127.0.0.1/$CONTAINER_SSH_PORT") 2>/dev/null; then
            break
        fi
        sleep 1
    done
cat <<EOF > "${LAUNCH_FILE}.tmp"

=====================================================================
 IDE session ready   (job ${SLURM_JOB_ID}, node ${NODE}, ends ${END_TIME})
=====================================================================

Your container is running on ${NODE}. It has its own /tmp and only sees:
  - ${PROJECT_DIR} (read/write)
  - your container home ${HOMEDIR} (read/write, contains .ssh and the vscode-server installation)
  - the additional data directories you selected
Everything else on the cluster is NOT visible, also not to agents/extensions started in this session.

1. Prerequisites (once)
   - VS Code with the extension "Remote - SSH" (ms-vscode-remote.remote-ssh)
   - an SSH key pair. The public key must be in
         ${AUTH_KEYS}
     (it was copied from /home/${USER}/.ssh/authorized_keys if that file existed, so the key you use for the cluster works)
   - private key on your workstation, e.g. C:/Users/${USER}/.ssh/${USER}.openssh. Please adpat the path below if you use a different one.


2. SSH config (C:/Users/${USER}/.ssh/config on Windows, ~/.ssh/config on Linux/Mac)
   Add these blocks once. For every new session ONLY "HostName" and "Port" of
   the block "hpc-ide" change - update them with the values below:

    Host ${LOGIN_HOST}
      HostName ${LOGIN_HOST}
      User ${USER}
      IdentityFile C:/Users/${USER}/.ssh/${USER}.openssh

    Host hpc-ide
      HostName ${NODE}.service
      Port ${CONTAINER_SSH_PORT}
      User ${USER}
      IdentityFile C:/Users/${USER}/.ssh/${USER}.openssh
      ProxyJump ${USER}@${LOGIN_HOST}:22
      HostKeyAlias hpc-ide
      StrictHostKeyChecking accept-new
      ServerAliveInterval 60

3. Connect
   - Fastest: open your project folder directly from a terminal on your workstation:

         code --remote ssh-remote+hpc-ide ${PROJECT_DIR}

   - Or in VS Code: F1 -> "Remote-SSH: Connect to Host..." -> hpc-ide, then
     "File -> Open Folder" and choose ${PROJECT_DIR}
   - A plain terminal login also starts in the project folder: ssh hpc-ide
   - Enter your key passphrase if you have set one (it may ask twice because of the jump host).
   - The first connection installs the vscode-server into ${HOMEDIR}/.vscode-server (takes a minute).
   - Install extensions in the remote window (they are stored in the container home and stay for the next sessions).

4. End of session
   - Files in /tmp of the container are deleted automatically when the session ends.
     Put everything you want to keep into ${PROJECT_DIR}.
   - Please stop the container when you are done, others are waiting for resources.
     In a terminal on the login node:
         scancel ${SLURM_JOB_ID}
   - The session ends automatically at ${END_TIME} (time limit).

If you have problems: the log of this session is /beegfs/${USER}/ide/logs/ (job ${SLURM_JOB_ID}).
Please contact your MAS admin.

EOF
    mv "${LAUNCH_FILE}.tmp" "${LAUNCH_FILE}"
) &

# --- container --------------------------------------------------------------
# --containall: clean env, own PID/IPC namespace, no automatic mount of home, tmp, cwd
# -H: persistent home of the container, same path inside and outside
cd "$PROJECT_DIR" || exit 1
singularity exec $NV --containall \
    -H "$HOMEDIR" \
    -B "$BINDS,$SSHD_CONFIG:$SSHD_CONFIG:ro" \
    "$IMAGE_PATH" \
    /usr/sbin/sshd -D -e -p "$CONTAINER_SSH_PORT" -f "$SSHD_CONFIG" &
SING_PID=$!
# wait is interrupted immediately by a signal, the trap above then runs
wait "$SING_PID"
RC=$?
printf 'container exited (rc=%s)\n' "$RC" 1>&2
