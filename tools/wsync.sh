#!/bin/bash
remote="master@10.0.0.173"
pass="xxxxxx"

pushd ~/projects/Windoze > /dev/null

if [[ "$1" = "up" ]]; then

    if [ ! -f ~/.ssh/id_rsa.pub ]; then
        ssh-keygen -t rsa -f ~/.ssh/id_rsa -N "" -q
    fi
    if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$remote" exit 2>/dev/null; then
        ssh-copy-id -o StrictHostKeyChecking=no "$remote"
    fi

    ssh -t "$remote" << EOF
echo "$pass" | sudo -S df . -h
if ! command -v rsync >/dev/null 2>&1; then
    sudo -S apt install rsync -y
fi
if [[ ! -d /opt/aevh ]]; then
    sudo -S mkdir -p /opt/aevh
    sudo -S chown -R master:master /opt/aevh
fi
EOF

    rsync -ah --info=progress2 opt/aevh "$remote":/opt
elif [[ "$1" = "down" ]]; then
    rsync -ah --info=progress2 "$remote":/opt/aevh opt
else
    echo "Utilização: $0 [up | down]"
fi
popd > /dev/null
