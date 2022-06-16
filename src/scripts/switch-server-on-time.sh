#!/bin/bash
DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"

. $DIR/utils/log_utils.sh
. $DIR/utils/json_utils.sh

headless=$(read_json_value "$DIR/../../config/config.json" headless)
. $DIR/switch-server.sh "$headless"
# Kill other instances of this script
# kill $(pgrep -f switch-server | grep -v ^$$\$) > /dev/null 2&>1
current_hour=$(date '+%H')

for server_file in $DIR/../../servers/json/*.json; do
    server_file_name=$(basename "$server_file")

    server_name=$(read_json_value "$server_file" name)
    reset_hour=$(read_json_value "$server_file" next-reset-hour)

    # Log independently for each server!
    set_logfile "$DIR/../../logs/$server_name-switch.log"

    # Just continue if its not time
    if [ "$current_hour" -ne "$reset_hour" ]; then
        echo "Not resetting on server $server_name. Target hour $reset_hour"
        log_msg "It is not time to reset. Target hour: $reset_hour"
        continue
    fi

    # Schedule new hour
    log_msg "Time to reset! Executing sequence Forking!. Server file $server_file_name"
        
    echo "Time to reset on server $server_name"
    # switch_main $server_file_name --update-hour > /dev/null 2>&1 &
    switch_main $server_file_name --update-hour

    echo "Sleeping 5 secs to avoid Same colab sheet problems"
    sleep 5
 done 
