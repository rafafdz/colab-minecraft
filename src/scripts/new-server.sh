DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"

# Include Logging
. $DIR/utils/log_utils.sh
. $DIR/utils/json_utils.sh

headless=$1

# Checks if port is running
check_service_port() {
    netstat -tupln 2> /dev/null | grep ":$1" > /dev/null
}

wait_service_port() {
    port=$1
    retries=1000
    for ((i=1;i<=retries;i++)); do
        if check_service_port $port; then
            log_msg "Service at port $port detected!"
            return 0
        fi

        # To do: DRY
        [ $(( $i % 5 )) -eq 0 ] && log_msg_error "Service not detected. Retrying: $i"
        sleep 2
    done

    log_msg_error "Failed in waiting service at port $port after $retries retries. Exiting"
    exit 1
}

execute_at_port(){
    if [ "$1" = "--root" ]; then
        user="root"
        shift
    else
        user="vps-user"
    fi
    port=$1
    cmd=$2    
    identity_file="$DIR/../../ssh-keys/colab_vps"
    ssh -q -i $identity_file -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" \
        -p $port "$user@localhost" "$cmd" 2> >(log_error) > >(log)
}


# Writes a message at the port assigned
execute_at_port_server(){
    execute_at_port $1 "tmux send-keys -t server:window1 '$2' Enter" 
}


check_server_contains_text_port(){
    # Warning! Checks for existance of WORD!!
    execute_at_port $1 "tmux capture-pane -t server:window1 -b temp-buffer -S -60 && \
                        tmux show-buffer -b temp-buffer | grep -w '$2'"
}

# To do: Make a command retry a function!
wait_server_text_port() {
    port=$1
    text=$2
    retries=1000
    for ((i=1;i<=retries;i++)); do
        if check_server_contains_text_port $port $text; then
            log_msg "Server ready at $port detected!"
            return 0
        fi
        # Log every multiple of 5
        [ $(( $i % 5 )) -eq 0 ] && log_msg_error "'$text' not detected. Retrying: $i"
        sleep 2
    done

    log_msg_error "Failed in waiting service at port $port after $retries retries. Exiting"
    exit 1
}

wait_server_ready_port(){
    wait_server_text_port $1 "Done"
}

wait_world_saved_port(){
    wait_server_text_port $1 "Saved the game"
}

create_reverse_daemon(){
    ssh_port=$1
    host_port=$2
    remote_port=$3
    execute_at_port --root $ssh_port "nohup \
     sh -c \"while true; do sshpass -p $reverse_password ssh -v -p $ssh_port_reverse -NT \
     -o 'ServerAliveInterval=60' -o 'ExitOnForwardFailure=yes' \
     -o 'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' \
     -R ${remote_port}:localhost:${host_port} $reverse_user@$reverse_domain; sleep 2; done\" \
     >> /home/vps-user/ssh-mc-daemon.log 2>&1 &"
}

get_new_server(){
    target_port=$1
    cookie_file=$2

    if check_service_port "$target_port"; then
        log_msg_error "Port $target_port is already in use!"
        return 1 
    fi
    
    pkill -f -9 colab-robot
    cd "$DIR/../colab-robot"
    # Run in headless mode when in production!
    if [ "$headless" = true ]; then
        xvfb-run -a $(which node) start-vps.js -u -p $target_port -c $cookie_file \
        --production 2>&1 | tee -a "$LOGFILE"
    else
        node start-vps.js -u -p $target_port -c $cookie_file 2>&1 | tee -a "$LOGFILE"
    fi
    retval=${PIPESTATUS[0]}
    cd "$DIR"
    return $retval
}

kill_reverse_on_port(){
    server_port=$1
    remote_port=$2
    # Trick to avoid substitution problem. Only bash!
    temp='kill $(pgrep -f <p>:)'
    cmd=${temp/<p>/$remote_port}
    execute_at_port --root $server_port "$cmd"
}


sync_server(){
    execute_at_port --root $1 "rsync \
     -e 'ssh -p $2 -i /content/colab_vps -o UserKnownHostsFile=/dev/null \
     -o StrictHostKeyChecking=no' -azvh --exclude cache \
     /home/vps-user/mc-server vps-user@$reverse_domain:~"
}


save_server_and_wait(){
    cmd="save-all"
    if [ $1 = "--flush" ]; then
        cmd="save-all flush"
        shift
    fi
    log_msg "Saving current world"
    execute_at_port_server $1 "$cmd"

    log_msg "Waiting for world save"
    wait_world_saved_port $1
}

extract_server(){
    execute_at_port $1 "cd ~ && tar xzf ~/server.tar.gz"
}

start_server(){
    execute_at_port $1 "cd ~; \
    tmux new-session -d -s server -n window1; \
    tmux send-keys -t server:window1 'cd ~/mc-server && ./start.sh' Enter"
}