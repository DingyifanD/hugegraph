#!/bin/bash

function abs_path() {
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    echo "$( cd -P "$( dirname "$SOURCE" )" && pwd )"
}

#read a property from a .properties file
function read_property(){
    # replace "." to "\."
    propertyName=`echo $2 | sed 's/\./\\\./g'`
    # file path
    fileName=$1;
    cat $fileName | sed -n -e "s/^[ ]*//g;/^#/d;s/^$propertyName=//p" | tail -1
}

BIN=`abs_path`
TOP="$(cd $BIN/../ && pwd)"

HSRV_URL=`read_property "$TOP/conf/rest-server.properties" "restserver.url"`

HSRV_STARTUP_TIMEOUT_S=20
HSRV_SHUTDOWN_TIMEOUT_S=20
SLEEP_INTERVAL_S=2

VERBOSE=

# wait_for_startup friendly_name host port timeout_s
function wait_for_startup() {

    local server_name="$1"
    local server_url="$2"
    local timeout_s="$3"

    local now_s=`date '+%s'`
    local stop_s=$(( $now_s + $timeout_s ))

    local status

    echo -n "Connecting to $server_name ($server_url)"
    while [ $now_s -le $stop_s ]; do
        echo -n .
        status=`curl -o /dev/null -s -w %{http_code} $server_url`
        if [ $status -eq 200 ]; then
            echo "OK"
            return 0
        fi
        sleep $SLEEP_INTERVAL_S
        now_s=`date '+%s'`
    done

    echo "timeout exceeded ($timeout_s seconds): could not connect to $server_url" >&2
    return 1
}

echo "Starting RestServer..."
if [ -n "$VERBOSE" ]; then
    "$BIN"/rest-server.sh "$TOP"/conf/rest-server.properties &
else
    "$BIN"/rest-server.sh "$TOP"/conf/rest-server.properties >/dev/null 2>&1 &
fi
wait_for_startup 'RestServer' "$HSRV_URL/graphs" $HSRV_STARTUP_TIMEOUT_S || {
    echo "See $TOP/logs/rest-server.log for RestServer log output." >&2
}
disown