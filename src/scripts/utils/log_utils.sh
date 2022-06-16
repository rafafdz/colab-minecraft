#!/bin/bash

# Bash 'Logging' Library. Should be sourced in other scripts

# No logile at first
LOGFILE=/dev/null

set_logfile(){
    LOGFILE=$1
}

read_all_lines(){
    out=""
    while read -r line || [[ -n "$line" ]]; do
        if [[ ! -z "$out" ]]; then
            out="$out\n$line"
        else
            out="$line"
        fi
    done
    echo "$out"
}

log(){ 
    if [[ "$1" !=  '' ]]; then extra_msg=" $1"; fi
    msg=$(read_all_lines)
    if [[ "$msg" != '' ]]; then
        printf "[$(date '+%d-%m %H:%M:%S')$extra_msg] ${msg}\n" | tee -a $LOGFILE
    fi
}

log_error(){
    msg=$(read_all_lines)
    [[ "$msg" != '' ]] && echo "$msg" | log "ERROR"
}

# To be called as a function instead of pipe!
log_msg(){
    echo "$@" | log
}

log_msg_error(){
    echo "$@" | log_error
}

# Attaches logger to stdin and stdout
log_cmd(){
    "$@" 2> >(log_error) > >(log)
}
