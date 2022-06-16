#!/bin/bash

# This script will be run on the server and will swap the running 
# colab machines

# Will be called every HOUR_DELTA hours by cron

DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"

headless=$1
# Include Logging
. $DIR/utils/log_utils.sh
. $DIR/utils/json_utils.sh
. $DIR/new-server.sh "$headless"
. $DIR/deploy-new-server.sh

HOUR_DELTA=10


set_next_hour(){
    server_file=$1
    current_hour=$(date '+%H')
    next_hour=$(( ( "10#$current_hour" + "10#$HOUR_DELTA" ) % 24 ))
    log_msg "Setting new hour to $next_hour"
    set_json_value $server_file next-reset-hour $next_hour
}

switch_main() {
    filename=$1
    update_hour_flag=$2
    server_file="$DIR/../../servers/json/$filename"
    identity_file="$DIR/../../ssh-keys/colab_vps"

    echo "Switching. Server file is $server_file"

    # Set up optional flag
    [[ "$update_hour_flag" = '--update-hour' ]] && update_hour=true

    if [ ! -f "$server_file" ]; then
        echo "'$server_file' not found. Exiting!"
        return 1
    fi


    server_name=$(read_json_value "$server_file" name)
    current_server_port=$(read_json_value "$server_file" ssh-port)
    temp_server_port=$(read_json_value "$server_file" ssh-switch-port)
    target_minecraft_port=$(read_json_value "$server_file" minecraft-port)
    cookie_file=$(read_json_value "$server_file" cookie-file)

    set_logfile "$DIR/../../logs/$server_name-switch.log"

    log_msg "Starting Switch of Server $server_name"
    log_msg "SSH port of server: $current_server_port"
    log_msg "Temp SSH port of server: $temp_server_port"

    if ! check_service_port $current_server_port; then
        log_msg "Server not running in port $current_server_port, Deploying!"
        deploy "$server_name"
        status=$?
        [[ $update_hour = true ]] && set_next_hour $server_file
        return $status
    fi

    # Create new instance
    log_msg "Starting server at port $temp_server_port, Cookie: $cookie_file"
    
    if ! get_new_server $temp_server_port $cookie_file; then
        log_msg "Error while getting new server. RIP"
        return 1
    fi
    
    # # Wait for 30 secs aprox
    log_msg "Waiting for ssh reverse connection"
    wait_service_port $temp_server_port

    
    log_msg "Disabling auto save"
    execute_at_port_server $current_server_port "save-off"

    save_server_and_wait $current_server_port   
    
    # Backup current server
    log_msg "Backing up server"
    execute_at_port $current_server_port "cd ~ && tar -zcf \
        ./server.tar.gz --exclude 'mc-server/cache' mc-server"

    # Copy file from current server
    log_msg "Copying server from current server"
    scp -q -i $identity_file -P $current_server_port -o "UserKnownHostsFile=/dev/null" \
        -o "StrictHostKeyChecking=no" "vps-user@localhost:~/server.tar.gz" \
        "$DIR/../../servers/tar/$server_name.transfer.tar.gz"

    # Copy file to new server
    log_msg "Copying server to new server"
    scp -q -i $identity_file -P $temp_server_port -o "UserKnownHostsFile=/dev/null" \
        -o "StrictHostKeyChecking=no" "$DIR/../../servers/tar/$server_name.transfer.tar.gz" \
        vps-user@localhost:~/server.tar.gz

    # Untar server and execute on new server
    log_msg "Unpacking server"
    extract_server $temp_server_port
    
    save_server_and_wait --flush $current_server_port
    sleep 5
    

    msg="El server se reiniciara en breve. El progreso de ahora no se guardará"
    while true; do execute_at_port_server $current_server_port "say $msg" > /dev/null 2 &> 1; sleep 5; done &
    msg_pid=$!

    log_msg "Syncing latest changes with new server"
    sync_server $current_server_port $temp_server_port
    # Sync twice to minimize corruption probability
    sync_server $current_server_port $temp_server_port
    log_msg "Server synced succesfully"

    log_msg "Starting server"
    start_server $temp_server_port

    wait_server_ready_port $temp_server_port
    log_msg "Server Ready!"

    kill $msg_pid
    execute_at_port_server $current_server_port "say El server se reiniciará en 5 segundos!"
    sleep 5
    log_msg "Stopping current server"
    execute_at_port_server $current_server_port "stop"

    # Kill current server minecraft connection
    log_msg "Killing current minecraft tunnel"
    kill_reverse_on_port $current_server_port $target_minecraft_port

    log_msg "Creating reverse minecraft connection on port $target_minectraft_port"
    create_reverse_daemon $temp_server_port 25565 $target_minecraft_port

    # Completely shutdown the old VPS
    log_msg "Killing old VPS"
    execute_at_port --root $current_server_port "kill 1"

    log_msg "Creating reverse ssh connection to port $current_server_port"
    create_reverse_daemon $temp_server_port 22 $current_server_port

    log_msg "Killing temp ssh"
    kill_reverse_on_port $temp_server_port $temp_server_port

    # Update next reset hour on server!
    [[ $update_hour = true ]] && set_next_hour $server_file

    log_msg "Script executed succesfully!"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # switch_main "$@"
    headless=$1
    server_file=$2
    update_hour_flag=$3
    switch_main "$server_file" "$update_hour_flag"
fi
