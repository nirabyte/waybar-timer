#!/bin/bash

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------
PRESETS=(1 5 10 15 20 25 30 45 60)
SCROLL_STEP=60
INACTIVITY_LIMIT=60

# Icons
ICON_DISABLED="󰔞 "
ICON_IDLE="󰔛"
ICON_SELECT="󱫣"
ICON_PAUSE="󱫟"
ICON_RUNNING="󱫡"
ICON_WARNING="󱫍"
ICON_DONE="󱫑"
ICON_RESET="󱫥"

# Files
STATE_FILE="/tmp/waybar_timer.json"
PID_FILE="/tmp/waybar_timer.pid"

# -----------------------------------------------------------------------------
# STATE MANAGEMENT
# -----------------------------------------------------------------------------

init_state() {
    # Always default to DISABLED on fresh init
    echo "DISABLED|0|0|0|$(date +%s)|0" > "$STATE_FILE"
}

read_state() {
    IFS='|' read -r STATE SEC_SET START_TIME PAUSE_REM LAST_ACT PRESET_IDX < "$STATE_FILE"
}

write_state() {
    # $1=State, $2=SecSet, $3=StartEpoch, $4=PauseRem, $5=LastAct, $6=PresetIdx
    echo "$1|$2|$3|$4|$5|$6" > "$STATE_FILE"
}

format_time() {
    local T=$1
    local MM=$((T / 60))
    local SS=$((T % 60))
    printf "%02d:%02d" "$MM" "$SS"
}

parse_duration() {
    local INPUT=$1
    local TOTAL_SECONDS=0

    # Remove spaces and convert to lowercase
    INPUT=$(echo "$INPUT" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

    # Handle different time units (hr/h, min/m, sec/s)
    # Process from largest to smallest units
    local NUM=""
    local UNIT=""

    for ((i=0; i<${#INPUT}; i++)); do
        char="${INPUT:i:1}"
        if [[ $char =~ [0-9] ]]; then
            NUM="${NUM}${char}"
        else
            # Found a unit character
            case $char in
                h)
                    if [ -n "$NUM" ]; then
                        TOTAL_SECONDS=$((TOTAL_SECONDS + NUM * 3600))
                        NUM=""
                    fi
                    ;;
                m)
                    if [ -n "$NUM" ]; then
                        TOTAL_SECONDS=$((TOTAL_SECONDS + NUM * 60))
                        NUM=""
                    fi
                    ;;
                s)
                    if [ -n "$NUM" ]; then
                        TOTAL_SECONDS=$((TOTAL_SECONDS + NUM))
                        NUM=""
                    fi
                    ;;
                r)
                    # Handle "hr" - check if this is part of "hr"
                    if [ $((i+1)) -lt ${#INPUT} ] && [ "${INPUT:$((i+1)):1}" = "r" ]; then
                        ((i++))  # Skip the 'r'
                        if [ -n "$NUM" ]; then
                            TOTAL_SECONDS=$((TOTAL_SECONDS + NUM * 3600))
                            NUM=""
                        fi
                    fi
                    ;;
                *)
                    # Invalid character
                    echo "Error: Invalid time format '$INPUT'. Use formats like: 10s, 1m30s, 1hr, 1hr20m2s" >&2
                    return 1
                    ;;
            esac
        fi
    done

    # Handle any remaining number (assume seconds if no unit)
    if [ -n "$NUM" ]; then
        TOTAL_SECONDS=$((TOTAL_SECONDS + NUM))
    fi

    # Validate minimum time (1 second)
    if [ "$TOTAL_SECONDS" -lt 1 ]; then
        TOTAL_SECONDS=60  # Default to 1 minute if too small
    fi

    echo "$TOTAL_SECONDS"
}

trigger_update() {
    # Send signal to main loop to wake up instantly
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill -SIGUSR1 "$PID"
        fi
    fi
}

# -----------------------------------------------------------------------------
# CONTROLLER (Handling Inputs)
# -----------------------------------------------------------------------------
if [ -n "$1" ]; then
    # Ensure state file exists before reading
    if [ ! -f "$STATE_FILE" ]; then init_state; fi

    read_state
    NOW=$(date +%s)
    NEW_ACT="$NOW"

    # Check if $1 looks like a time duration (contains digits and time units)
    if echo "$1" | grep -qE '^[0-9]+[smhr]*([0-9]+[smhr]*)*$'; then
        # Parse time duration directly
        PARSED_TIME=$(parse_duration "$1")
        if [ $? -ne 0 ] || [ -z "$PARSED_TIME" ]; then
            echo "Error: Invalid duration format '$1'. Examples: 10s, 1m30s, 1hr, 1hr20m2s" >&2
            exit 1
        fi

        case "$STATE" in
            "RUNNING")
                # If running, adjust the remaining time
                ELAPSED=$(( NOW - START_TIME ))
                NEW_SET=$(( ELAPSED + PARSED_TIME ))
                write_state "RUNNING" "$NEW_SET" "$START_TIME" "0" "$NEW_ACT" "$PRESET_IDX"
                ;;
            "PAUSED")
                # If paused, set new paused time
                write_state "PAUSED" "$PARSED_TIME" "0" "$PARSED_TIME" "$NEW_ACT" "$PRESET_IDX"
                ;;
            *)
                # For other states, set and start the timer
                write_state "RUNNING" "$PARSED_TIME" "$NOW" "0" "$NEW_ACT" "$PRESET_IDX"
                ;;
        esac
        trigger_update
        exit 0
    fi

    case "$1" in
        "up"|"down")
            MOD=$SCROLL_STEP
            [ "$1" == "down" ] && MOD=$(( -SCROLL_STEP ))

            if [ "$STATE" == "RUNNING" ]; then
                ELAPSED=$(( NOW - START_TIME ))
                REM=$(( SEC_SET - ELAPSED ))
                NEW_REM=$(( REM + MOD ))
                if [ "$NEW_REM" -le 0 ]; then NEW_REM=1; fi
                # Recalculate Set time to match new remaining
                NEW_SET=$(( NEW_REM + (NOW - START_TIME) ))
                write_state "RUNNING" "$NEW_SET" "$START_TIME" "0" "$NEW_ACT" "$PRESET_IDX"

            elif [ "$STATE" == "PAUSED" ]; then
                NEW_REM=$(( PAUSE_REM + MOD ))
                [ "$NEW_REM" -lt 1 ] && NEW_REM=60
                write_state "PAUSED" "$SEC_SET" "0" "$NEW_REM" "$NEW_ACT" "$PRESET_IDX"

            elif [ "$STATE" == "SELECT" ] || [ "$STATE" == "IDLE" ]; then
                NEW_SET=$(( SEC_SET + MOD ))
                [ "$NEW_SET" -lt 60 ] && NEW_SET=60
                write_state "SELECT" "$NEW_SET" "0" "0" "$NEW_ACT" "$PRESET_IDX"
            fi
            ;;

        "click") # Left Click
            case "$STATE" in
                "DISABLED")
                    write_state "IDLE" "0" "0" "0" "$NEW_ACT" "0" ;;
                "IDLE")
                    DEFAULT_SEC=$(( ${PRESETS[0]} * 60 ))
                    write_state "SELECT" "$DEFAULT_SEC" "0" "0" "$NEW_ACT" "0" ;;
                "SELECT")
                    write_state "RUNNING" "$SEC_SET" "$NOW" "0" "$NEW_ACT" "$PRESET_IDX" ;;
                "RUNNING")
                    ELAPSED=$(( NOW - START_TIME ))
                    REM=$(( SEC_SET - ELAPSED ))
                    write_state "PAUSED" "$SEC_SET" "0" "$REM" "$NEW_ACT" "$PRESET_IDX" ;;
                "PAUSED")
                    NEW_START=$(( NOW - SEC_SET + PAUSE_REM ))
                    write_state "RUNNING" "$SEC_SET" "$NEW_START" "0" "$NEW_ACT" "$PRESET_IDX" ;;
                "DONE")
                    write_state "IDLE" "0" "0" "0" "$NEW_ACT" "0" ;;
            esac
            ;;

        "right") # Right Click
             if [ "$STATE" == "IDLE" ]; then
                 # Only Disable if state is 00:00 (IDLE)
                 write_state "DISABLED" "0" "0" "0" "$NEW_ACT" "0"

             elif [ "$STATE" == "SELECT" ]; then
                 # Cycle Presets if Timer is set but not running
                 NEXT=$(( PRESET_IDX + 1 ))
                 if [ "$NEXT" -ge "${#PRESETS[@]}" ]; then NEXT=0; fi
                 NEW_TIME=$(( ${PRESETS[$NEXT]} * 60 ))
                 write_state "SELECT" "$NEW_TIME" "0" "0" "$NEW_ACT" "$NEXT"

             elif [ "$STATE" == "RUNNING" ] || [ "$STATE" == "PAUSED" ]; then
                 # Pause/Resume if running
                 $0 click
                 exit 0
             fi
             ;;

        "middle") # Reset
             write_state "RESET_ANIM" "0" "0" "0" "$NEW_ACT" "0"
             ;;

        "set") # Set specific time duration
            if [ -z "$2" ]; then
                echo "Error: 'set' requires a duration argument. Examples: 10s, 1m30s, 1hr, 1hr20m2s" >&2
                exit 1
            fi

            PARSED_TIME=$(parse_duration "$2")
            if [ $? -ne 0 ] || [ -z "$PARSED_TIME" ]; then
                echo "Error: Invalid duration format '$2'. Examples: 10s, 1m30s, 1hr, 1hr20m2s" >&2
                exit 1
            fi

            case "$STATE" in
                "RUNNING")
                    # If running, adjust the remaining time
                    ELAPSED=$(( NOW - START_TIME ))
                    NEW_SET=$(( ELAPSED + PARSED_TIME ))
                    write_state "RUNNING" "$NEW_SET" "$START_TIME" "0" "$NEW_ACT" "$PRESET_IDX"
                    ;;
                "PAUSED")
                    # If paused, set new paused time
                    write_state "PAUSED" "$PARSED_TIME" "0" "$PARSED_TIME" "$NEW_ACT" "$PRESET_IDX"
                    ;;
                *)
                    # For other states, set as selected time
                    write_state "SELECT" "$PARSED_TIME" "0" "0" "$NEW_ACT" "$PRESET_IDX"
                    ;;
            esac
            ;;
    esac

    trigger_update
    exit 0
fi

# -----------------------------------------------------------------------------
# SERVER LOOP (Waybar Output)
# -----------------------------------------------------------------------------
# On startup (reboot or waybar reload), force DISABLED state
init_state
echo $$ > "$PID_FILE"

# Trap SIGUSR1 for instant updates
trap : SIGUSR1

while true; do
    read_state
    NOW=$(date +%s)

    TEXT=""
    ICON=""
    CLASS="$STATE"
    TOOLTIP=""

    case "$STATE" in
        "DISABLED")
            ICON="$ICON_DISABLED"
            CLASS="disabled"
            TOOLTIP="Timer Disabled\nLeft-Click to Activate"

            echo "{\"text\": \"$ICON\", \"tooltip\": \"$TOOLTIP\", \"class\": \"$CLASS\"}"

            # SUSPEND EXECUTION (0% CPU)
            # 'sleep infinity' runs in background.
            # 'wait' blocks until a signal (click) is received.
            sleep infinity &
            SLEEP_PID=$!
            wait $SLEEP_PID
            kill $SLEEP_PID 2>/dev/null
            continue
            ;;

        "IDLE")
            ICON="$ICON_IDLE"
            TEXT="00:00"
            CLASS="idle"
            TOOLTIP="Timer Idle\nLeft-Click: Set Time\nRight-Click: Disable\nScroll: Adjust Time(± 60s)"

            if [ $(( NOW - LAST_ACT )) -gt "$INACTIVITY_LIMIT" ]; then
                write_state "DISABLED" "0" "0" "0" "$NOW" "0"
                trigger_update
                continue
            fi
            ;;

        "SELECT")
            ICON="$ICON_SELECT"
            TEXT="$(format_time $SEC_SET)"
            CLASS="select"
            TOOLTIP="Set Timer\nLeft-Click: Start\nRight-Click: Next Preset\nScroll: Adjust Time(± 60s)"

            if [ $(( NOW - LAST_ACT )) -gt "$INACTIVITY_LIMIT" ]; then
                write_state "DISABLED" "0" "0" "0" "$NOW" "0"
                trigger_update
                continue
            fi
            ;;

        "RUNNING")
            ELAPSED=$(( NOW - START_TIME ))
            REMAINING=$(( SEC_SET - ELAPSED ))

            if [ "$REMAINING" -le 0 ]; then
                # Notification stays for 3.5 seconds (3500ms)
                notify-send -u critical -t 3500 -i clock "Timer" "Timer Finished!" &
                write_state "DONE" "$SEC_SET" "0" "0" "$NOW" "0"
                trigger_update
                continue
            fi

            # ALERT LOGIC:
            # 1. 30s Mark: Show warning icon (30, 29, 28)
            # 2. Critical: Show warning icon if <= 10 seconds
            if [ "$REMAINING" -le 30 ] && [ "$REMAINING" -gt 27 ]; then
                ICON="$ICON_WARNING"
                CLASS="warning"
            elif [ "$REMAINING" -le 10 ]; then
                ICON="$ICON_WARNING"
                CLASS="warning"
            else
                ICON="$ICON_RUNNING"
                CLASS="running"
            fi

            TEXT="$(format_time $REMAINING)"
            TOOLTIP="Running\nLeft-Click: Pause\nScroll: Adjust Time(± 60s)\nMiddle-Click: Reset"
            ;;

        "PAUSED")
            ICON="$ICON_PAUSE"
            TEXT="$(format_time $PAUSE_REM)"
            CLASS="paused"
            TOOLTIP="Paused\nLeft-Click: Resume"
            ;;

        "DONE")
            ICON="$ICON_DONE"
            TEXT="00:00"
            CLASS="done"
            TOOLTIP="Timer Finished"
            if [ $(( NOW - LAST_ACT )) -gt 4 ]; then
                write_state "IDLE" "0" "0" "0" "$NOW" "0"
                trigger_update
                continue
            fi
            ;;

        "RESET_ANIM")
             echo "{\"text\": \"$ICON_RESET --:--\", \"class\": \"reset\", \"tooltip\": \"Resetting...\"}"
             sleep 0.2
             write_state "IDLE" "0" "0" "0" "$NOW" "0"
             continue
             ;;
    esac

    echo "{\"text\": \"$ICON $TEXT\", \"tooltip\": \"$TOOLTIP\", \"class\": \"$CLASS\"}"

    # STANDARD LOOP WAIT
    # Wait 1s for timer tick OR signal for instant update
    sleep 1 &
    SLEEP_PID=$!
    wait $SLEEP_PID
    kill $SLEEP_PID 2>/dev/null

done
