#!/bin/bash
DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"

. $DIR/utils/log_utils.sh
. $DIR/utils/json_utils.sh

headless=$(read_json_value "$DIR/../../config/config.json" headless)
. $DIR/new-server.sh "$headless"

deploy(){
    server_name=$1
    tar_path="$DIR/../../servers/tar/$server_name.tar.gz"
    server_file="$DIR/../../servers/json/$server_name.json"
    identity_file="$DIR/../../ssh-keys/colab_vps"

    server_name=$(read_json_value "$server_file" name)
    target_port=$(read_json_value "$server_file" ssh-port)
    minecraft_port=$(read_json_value "$server_file" minecraft-port)
    cookie_file=$(read_json_value "$server_file" cookie-file)

    set_logfile "$DIR/../../logs/$server_name-deploy.log"

    log_msg "Starting Deploy of Server $server_name"

    log_msg "Getting new server on port $target_port"

    if ! get_new_server $target_port $cookie_file; then
        log_msg_error "Error at deploying server $server_name on $target_port."
        exit 1
    fi

    log_msg "Waiting server!"
    wait_service_port $target_port

    log_msg "Copying file: $tar_path"
    scp -q -i $identity_file -P $target_port -o "UserKnownHostsFile=/dev/null" \
    -o "StrictHostKeyChecking=no" $tar_path "vps-user@localhost:~/server.tar.gz"

    # Untar server and execute on new server
    log_msg "Extracting tar"
    extract_server $target_port

    log_msg "Starting Server"
    start_server $target_port

    wait_server_ready_port $target_port
    log_msg "Server Ready!"

    log_msg "Creating reverse minecraft connection"
    create_reverse_daemon $target_port 25565 $minecraft_port

    log_msg "Succesfully set up server $server_name. Connect to ssh at port $target_port"
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    server_name=$1
    deploy "$server_name"
fi
