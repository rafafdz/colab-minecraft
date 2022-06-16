#!/bin/bash

DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"

usage() {
    echo "Usage:"
    echo "For deploying new server: "
    echo "  ./colab-minecraft.sh deploy <server_name>"
    echo ""
    echo "For keeping servers alive (switching). Recommended on cron every hour"
    echo "  ./colab-minecraft.sh switch"
    exit 1
}

[ $# -gt 2 ] && usage

cmd=$1
[ "$cmd" != "deploy" ] && [ "$cmd" != "switch" ] && usage


if ! [ -d "$DIR/src/colab-robot/node_modules" ]; then
    echo "Executing first install"
    cd "$DIR/src/colab-robot"
    npm install
    cd $DIR
fi

if [ "$cmd" = "deploy" ]; then
    name=$2
    [ -z $name ] && usage
    "$DIR/src/scripts/deploy-new-server.sh" $name
    exit 0
fi

"$DIR/src/scripts/switch-server-on-time.sh" 