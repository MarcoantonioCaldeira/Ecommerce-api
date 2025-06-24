#!/bin/sh
# Use this script to test if a given TCP host/port are available

WAITFORIT_cmdname=${0##*/}

echoerr() { if [ "$WAITFORIT_QUIET" -ne 1 ]; then echo "$@" 1>&2; fi } # Changed [[ ]] to [ ]

usage()
{
    cat << USAGE >&2
Usage:
    $WAITFORIT_cmdname host:port [-s] [-t timeout] [-- command args]
    -h HOST | --host=HOST       Host or IP under test
    -p PORT | --port=PORT       TCP port under test
                                Alternatively, you specify the host and port as host:port
    -s | --strict               Only execute subcommand if the test succeeds
    -q | --quiet                Don't output any status messages
    -t TIMEOUT | --timeout=TIMEOUT
                                Timeout in seconds, zero for no timeout
    -- COMMAND ARGS             Execute command with args after the test finishes
USAGE
    exit 1
}

wait_for()
{
    if [ "$WAITFORIT_TIMEOUT" -gt 0 ]; then # Changed [[ ]] to [ ]
        echoerr "$WAITFORIT_cmdname: waiting $WAITFORIT_TIMEOUT seconds for $WAITFORIT_HOST:$WAITFORIT_PORT"
    else
        echoerr "$WAITFORIT_cmdname: waiting for $WAITFORIT_HOST:$WAITFORIT_PORT without a timeout"
    fi
    WAITFORIT_start_ts=$(date +%s)
    while :
    do
        if [ "$WAITFORIT_ISBUSY" -eq 1 ]; then # Changed [[ ]] to [ ]
            nc -z "$WAITFORIT_HOST" "$WAITFORIT_PORT" # Added quotes for robustness
            WAITFORIT_result=$?
        else
            (echo -n > "/dev/tcp/$WAITFORIT_HOST/$WAITFORIT_PORT") >/dev/null 2>&1 # Added quotes for robustness
            WAITFORIT_result=$?
        fi
        if [ "$WAITFORIT_result" -eq 0 ]; then # Changed [[ ]] to [ ]
            WAITFORIT_end_ts=$(date +%s)
            echoerr "$WAITFORIT_cmdname: $WAITFORIT_HOST:$WAITFORIT_PORT is available after $((WAITFORIT_end_ts - WAITFORIT_start_ts)) seconds"
            break
        fi
        sleep 1
    done
    return $WAITFORIT_result
}

wait_for_wrapper()
{
    # In order to support SIGINT during timeout: http://unix.stackexchange.com/a/57692
    if [ "$WAITFORIT_QUIET" -eq 1 ]; then # Changed [[ ]] to [ ]
        timeout "$WAITFORIT_BUSYTIMEFLAG" "$WAITFORIT_TIMEOUT" "$0" --quiet --child --host="$WAITFORIT_HOST" --port="$WAITFORIT_PORT" --timeout="$WAITFORIT_TIMEOUT" & # Added quotes
    else
        timeout "$WAITFORIT_BUSYTIMEFLAG" "$WAITFORIT_TIMEOUT" "$0" --child --host="$WAITFORIT_HOST" --port="$WAITFORIT_PORT" --timeout="$WAITFORIT_TIMEOUT" & # Added quotes
    fi
    WAITFORIT_PID=$!
    trap "kill -INT -$WAITFORIT_PID" INT
    wait $WAITFORIT_PID
    WAITFORIT_RESULT=$?
    if [ "$WAITFORIT_RESULT" -ne 0 ]; then # Changed [[ ]] to [ ]
        echoerr "$WAITFORIT_cmdname: timeout occurred after waiting $WAITFORIT_TIMEOUT seconds for $WAITFORIT_HOST:$WAITFORIT_PORT"
    fi
    return $WAITFORIT_RESULT
}

# process arguments
WAITFORIT_CLI="" # Initialize as empty string for sh compatibility
while [ $# -gt 0 ] # Changed [[ ]] to [ ]
do
    case "$1" in
        *:* )
        # Use simple string manipulation instead of bash array
        WAITFORIT_HOST=$(echo "$1" | cut -d':' -f1)
        WAITFORIT_PORT=$(echo "$1" | cut -d':' -f2)
        shift 1
        ;;
        --child)
        WAITFORIT_CHILD=1
        shift 1
        ;;
        -q | --quiet)
        WAITFORIT_QUIET=1
        shift 1
        ;;
        -s | --strict)
        WAITFORIT_STRICT=1
        shift 1
        ;;
        -h)
        WAITFORIT_HOST="$2"
        if [ -z "$WAITFORIT_HOST" ]; then usage; fi # Changed [[ ]] to [ ], and break to usage
        shift 2
        ;;
        --host=*)
        WAITFORIT_HOST="${1#*=}"
        shift 1
        ;;
        -p)
        WAITFORIT_PORT="$2"
        if [ -z "$WAITFORIT_PORT" ]; then usage; fi # Changed [[ ]] to [ ], and break to usage
        shift 2
        ;;
        --port=*)
        WAITFORIT_PORT="${1#*=}"
        shift 1
        ;;
        -t)
        WAITFORIT_TIMEOUT="$2"
        if [ -z "$WAITFORIT_TIMEOUT" ]; then usage; fi # Changed [[ ]] to [ ], and break to usage
        shift 2
        ;;
        --timeout=*)
        WAITFORIT_TIMEOUT="${1#*=}"
        shift 1
        ;;
        --)
        shift
        # Accumulate arguments for the command
        for arg in "$@"; do
            WAITFORIT_CLI="$WAITFORIT_CLI \"$arg\""
        done
        # No need to break here, the loop will exit naturally when shift consumes all args
        break # Keep this break, as it exits the while loop after processing '--'
        ;;
        --help)
        usage
        ;;
        *)
        echoerr "Unknown argument: $1"
        usage
        ;;
    esac
done

if [ -z "$WAITFORIT_HOST" ] || [ -z "$WAITFORIT_PORT" ]; then # Changed [[ ]] to [ ] and added -z
    echoerr "Error: you need to provide a host and port to test."
    usage
fi

WAITFORIT_TIMEOUT=${WAITFORIT_TIMEOUT:-15}
WAITFORIT_STRICT=${WAITFORIT_STRICT:-0}
WAITFORIT_CHILD=${WAITFORIT_CHILD:-0}
WAITFORIT_QUIET=${WAITFORIT_QUIET:-0}

# Check to see if timeout is from busybox?
WAITFORIT_TIMEOUT_PATH=$(type -p timeout)
WAITFORIT_TIMEOUT_PATH=$(realpath "$WAITFORIT_TIMEOUT_PATH" 2>/dev/null || readlink -f "$WAITFORIT_TIMEOUT_PATH") # Added quotes

WAITFORIT_BUSYTIMEFLAG=""
if echo "$WAITFORIT_TIMEOUT_PATH" | grep -q "busybox"; then # Changed [[ =~ ]] to echo | grep -q
    WAITFORIT_ISBUSY=1
    # Check if busybox timeout uses -t flag
    # (recent Alpine versions don't support -t anymore)
    if timeout &>/dev/stdout | grep -q -e '-t '; then
        WAITFORIT_BUSYTIMEFLAG="-t"
    fi
else
    WAITFORIT_ISBUSY=0
fi

if [ "$WAITFORIT_CHILD" -gt 0 ]; then # Changed [[ ]] to [ ]
    wait_for
    WAITFORIT_RESULT=$?
    exit "$WAITFORIT_RESULT"
else
    if [ "$WAITFORIT_TIMEOUT" -gt 0 ]; then # Changed [[ ]] to [ ]
        wait_for_wrapper
        WAITFORIT_RESULT=$?
    else
        wait_for
        WAITFORIT_RESULT=$?
    fi
fi

if [ -n "$WAITFORIT_CLI" ]; then # Changed [[ ]] to [ ] and != "" to -n
    if [ "$WAITFORIT_RESULT" -ne 0 ] && [ "$WAITFORIT_STRICT" -eq 1 ]; then # Changed [[ ]] to [ ]
        echoerr "$WAITFORIT_cmdname: strict mode, refusing to execute subprocess"
        exit "$WAITFORIT_RESULT"
    fi
    # Use eval to execute the command with arguments, as they were concatenated into a string
    eval exec "$WAITFORIT_CLI"
else
    exit "$WAITFORIT_RESULT"
fi