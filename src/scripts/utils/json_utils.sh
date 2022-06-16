
# Simply returns the value of a key in a json file. Does not works with arrays
read_json_value(){
    filename="$1"
    key="$2"
    script="import json,sys;obj=json.load(sys.stdin);print(obj['$key'])"
    res=$(cat $filename | python3 -c "$script" 2> /dev/null)
    [[ ! "$?" ]] && echo "Error" && return 1
    printf "$res"
}


set_json_value(){
    filename="$1"
    key="$2"
    new_val="$3"
    script="import json,sys;obj=json.load(sys.stdin);obj['$key']=$new_val;print(json.dumps(obj, indent=4))"
    res=$(cat $filename | python3 -c "$script")
    [[ ! "$?" ]] && echo "Error" && return 1
    printf "$res" > $filename
}