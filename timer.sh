#!/bin/bash

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

# --- STANDARD TIMER PRESETS (Seconds) ---
PRESETS=(0 30 60 300 600 900 1200 1500 1800 2700 3000 3600 4500 5400 6300 7200 9000 10800)
SCROLL_STEP=60
INACTIVITY_LIMIT=30

# --- POMODORO INITIAL PRESET ---
POMO_PRESETS=(
    "25 5 4"
)

# Pomodoro Settings
POMO_AUTO_BREAK=true
POMO_AUTO_WORK=true

# --- SOUND EFFECTS ---
SOUND_TIMER_DONE="${HOME}/.config/waybar/sounds/timer.mp3"
SOUND_WORK_START="${HOME}/.config/waybar/sounds/timer.mp3"
SOUND_BREAK_START="${HOME}/.config/waybar/sounds/timer.mp3"
SOUND_BREAK_END="${HOME}/.config/waybar/sounds/timer.mp3"
SOUND_COMPLETE="${HOME}/.config/waybar/sounds/timer.mp3"

# --- ICONS ---
ICON_DISABLED="󰔞 "
ICON_IDLE="󰔛"
ICON_SELECT="󱫣"
ICON_PAUSE="󱫟"
ICON_RUNNING="󱫡"
ICON_WARNING="󱫍"
ICON_DONE="󱫑"
ICON_RESET="󱫥"

# Pomodoro Icons
ICON_POMO_IDLE=""
ICON_POMO_START=""
ICON_POMO_HALF=""
ICON_POMO_END=""
ICON_POMO_DONE=""
ICON_POMO_BREAK=""

# Files (Optimized to use RAM instead of Disk)
STATE_FILE="/dev/shm/waybar_timer.json"
PIPE_FILE="/tmp/waybar_timer.fifo"

# --- HELPER FUNCTION FOR SOUND ---
play_sound() {
    local sound_file="$1"
    # Expand ~ to home directory
    sound_file="${sound_file/#\~/$HOME}"
    if [ -f "$sound_file" ]; then
        paplay "$sound_file" 2>/dev/null &
    else
        echo "Warning: Sound file not found: $sound_file" >&2
    fi
}

# -----------------------------------------------------------------------------
# STATE MANAGEMENT
# -----------------------------------------------------------------------------

init_state() {
    # Using builtin printf for time to save CPU (no 'date' process spawned)
    printf -v NOW '%(%s)T' -1
    echo "DISABLED|0|0|0|$NOW|0|0|0|1|1|5|1|0" > "$STATE_FILE"
}

read_state() {
    IFS='|' read -r STATE SEC_SET START_TIME PAUSE_REM LAST_ACT PRESET_IDX MODE P_STAGE P_CURRENT P_TOTAL P_WORK_LEN P_BREAK_LEN P_EDIT_FOCUS < "$STATE_FILE"
    if [ -z "$P_EDIT_FOCUS" ]; then init_state; read_state; fi
}

write_state() {
    echo "$1|$2|$3|$4|$5|$6|$7|$8|$9|${10}|${11}|${12}|${13}" > "$STATE_FILE"
}

WS() { write_state "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}"; }

format_time() {
    local T=$1
    local HH=$((T / 3600))
    local MM=$(( (T % 3600) / 60 ))
    local SS=$((T % 60))
    if [ "$HH" -gt 0 ]; then printf "%d:%02d:%02d" "$HH" "$MM" "$SS"; else printf "%02d:%02d" "$MM" "$SS"; fi
}

trigger_update() {
    # OPTIMIZATION: Instead of slow pkill/signals, we simply write a byte to the FIFO.
    # This breaks the 'read -t 1' loop in the server instance INSTANTLY.
    if [ -p "$PIPE_FILE" ]; then
        echo "1" > "$PIPE_FILE" &
    fi
}

# -----------------------------------------------------------------------------
# CONTROLLER
# -----------------------------------------------------------------------------
if [ -n "$1" ]; then
    if [ ! -f "$STATE_FILE" ]; then init_state; fi
    read_state

    # Builtin time fetch
    printf -v NOW '%(%s)T' -1
    NEW_ACT="$NOW"

    case "$1" in
        # --- POMODORO CLI ARGUMENTS ---
        "pomo")
            shift # Remove 'pomo' from arguments
            ARGS="$*"

            # Defaults
            W=25; B=5; S=4

            # Check if input uses m/b/s format (e.g. 25m 5b 4s)
            if [[ "$ARGS" =~ [0-9]+[mbs] ]]; then
                [[ "$ARGS" =~ ([0-9]+)m ]] && W="${BASH_REMATCH[1]}"
                [[ "$ARGS" =~ ([0-9]+)b ]] && B="${BASH_REMATCH[1]}"
                [[ "$ARGS" =~ ([0-9]+)s ]] && S="${BASH_REMATCH[1]}"
            else
                # Fallback to positional: Work Break Sessions (e.g. 25 5 4)
                if [ -n "$1" ]; then W="$1"; fi
                if [ -n "$2" ]; then B="$2"; fi
                if [ -n "$3" ]; then S="$3"; fi
            fi

            # Validate minimums
            [ "$W" -lt 1 ] && W=1
            [ "$B" -lt 1 ] && B=1
            [ "$S" -lt 1 ] && S=1

            # Start Pomodoro (State: POMO_MSG -> automatically switches to RUNNING)
            WS "POMO_MSG" "$((W*60))" "$NOW" "0" "$NEW_ACT" "0" "1" "0" "1" "$S" "$W" "$B" "0"
            trigger_update; exit 0
            ;;

        # --- STANDARD INTERACTION ---
        "up"|"down")
            MOD=$SCROLL_STEP
            [ "$1" == "down" ] && MOD=$(( -SCROLL_STEP ))


        # --- IDLE STATE ---
            if [ "$STATE" == "IDLE" ]; then
                if [ "$1" == "up" ]; then
                    WS "SELECT" "0" "0" "0" "$NEW_ACT" "0" "0" "0" "0" "0" "0" "0" "0"
                else
                    read -r w b s <<< "${POMO_PRESETS[0]}"
                    WS "SELECT" "$((w*60))" "0" "0" "$NEW_ACT" "0" "1" "0" "1" "$s" "$w" "$b" "0"
                fi
                trigger_update; exit 0
            fi

            # --- SELECT MODE ---
            if [ "$STATE" == "SELECT" ]; then
                if [ "$MODE" == "0" ]; then
                    NEW_SET=$(( SEC_SET + MOD ))
                    if [ "$NEW_SET" -lt 30 ]; then
                        WS "IDLE" "0" "0" "0" "$NEW_ACT" "0" "0" "0" "0" "0" "0" "0" "0"
                    else
                        WS "SELECT" "$NEW_SET" "0" "0" "$NEW_ACT" "$PRESET_IDX" "0" "0" "0" "0" "0" "0" "0"
                    fi
                else
                    case "$P_EDIT_FOCUS" in
                        0) NEW_W=$(( P_WORK_LEN + (MOD/60) ))
                           if [ "$NEW_W" -lt 1 ]; then
                               WS "IDLE" "0" "0" "0" "$NEW_ACT" "0" "0" "0" "0" "0" "0" "0" "0"
                           else
                               NEW_SET=$(( NEW_W * 60 ))
                               WS "SELECT" "$NEW_SET" "0" "0" "$NEW_ACT" "$PRESET_IDX" "1" "0" "1" "$P_TOTAL" "$NEW_W" "$P_BREAK_LEN" "0"
                           fi ;;
                        1) NEW_B=$(( P_BREAK_LEN + (MOD/60) ))
                           [ "$NEW_B" -lt 1 ] && NEW_B=1
                           WS "SELECT" "$SEC_SET" "0" "0" "$NEW_ACT" "$PRESET_IDX" "1" "0" "1" "$P_TOTAL" "$P_WORK_LEN" "$NEW_B" "1" ;;
                        2) S_MOD=1; [ "$1" == "down" ] && S_MOD=-1
                           NEW_S=$(( P_TOTAL + S_MOD ))
                           [ "$NEW_S" -lt 1 ] && NEW_S=1
                           WS "SELECT" "$SEC_SET" "0" "0" "$NEW_ACT" "$PRESET_IDX" "1" "0" "1" "$NEW_S" "$P_WORK_LEN" "$P_BREAK_LEN" "2" ;;
                    esac
                fi
                trigger_update; exit 0
            fi

            # --- RUNNING / PAUSED ---
            if [ "$STATE" == "RUNNING" ]; then
                ELAPSED=$(( NOW - START_TIME ))
                REM=$(( SEC_SET - ELAPSED ))
                NEW_REM=$(( REM + MOD ))
                if [ "$NEW_REM" -le 0 ]; then NEW_REM=1; fi
                NEW_SET=$(( NEW_REM + (NOW - START_TIME) ))
                WS "RUNNING" "$NEW_SET" "$START_TIME" "0" "$NEW_ACT" "$PRESET_IDX" "$MODE" "$P_STAGE" "$P_CURRENT" "$P_TOTAL" "$P_WORK_LEN" "$P_BREAK_LEN" "$P_EDIT_FOCUS"

            elif [ "$STATE" == "PAUSED" ]; then
                NEW_REM=$(( PAUSE_REM + MOD ))
                [ "$NEW_REM" -lt 1 ] && NEW_REM=60
                WS "PAUSED" "$SEC_SET" "0" "$NEW_REM" "$NEW_ACT" "$PRESET_IDX" "$MODE" "$P_STAGE" "$P_CURRENT" "$P_TOTAL" "$P_WORK_LEN" "$P_BREAK_LEN" "$P_EDIT_FOCUS"
            fi
            ;;

        "click")
                 case "$STATE" in
                     "DISABLED") WS "IDLE" "0" "0" "0" "$NEW_ACT" "0" "0" "0" "0" "0" "0" "0" "0" ;;
                     "IDLE")     WS "SELECT" "0" "0" "0" "$NEW_ACT" "0" "0" "0" "0" "0" "0" "0" "0" ;;
                     "SELECT")

                    if [ "$MODE" == "1" ]; then
                         WS "POMO_MSG" "$SEC_SET" "$NOW" "0" "$NEW_ACT" "$PRESET_IDX" "1" "0" "1" "$P_TOTAL" "$P_WORK_LEN" "$P_BREAK_LEN" "$P_EDIT_FOCUS"
                    else
                         WS "RUNNING" "$SEC_SET" "$NOW" "0" "$NEW_ACT" "$PRESET_IDX" "0" "0" "0" "0" "0" "0" "0"
                    fi ;;
                "RUNNING")
                    ELAPSED=$(( NOW - START_TIME ))
                    REM=$(( SEC_SET - ELAPSED ))
                    WS "PAUSED" "$SEC_SET" "0" "$REM" "$NEW_ACT" "$PRESET_IDX" "$MODE" "$P_STAGE" "$P_CURRENT" "$P_TOTAL" "$P_WORK_LEN" "$P_BREAK_LEN" "$P_EDIT_FOCUS" ;;
                "PAUSED")
                    NEW_START=$(( NOW - SEC_SET + PAUSE_REM ))
                    WS "RUNNING" "$SEC_SET" "$NEW_START" "0" "$NEW_ACT" "$PRESET_IDX" "$MODE" "$P_STAGE" "$P_CURRENT" "$P_TOTAL" "$P_WORK_LEN" "$P_BREAK_LEN" "$P_EDIT_FOCUS" ;;
                "DONE")     WS "IDLE" "0" "0" "0" "$NEW_ACT" "0" "0" "0" "0" "0" "0" "0" "0" ;;
            esac
            ;;

        "right")
             if [ "$STATE" == "IDLE" ]; then
                 WS "DISABLED" "0" "0" "0" "$NEW_ACT" "0" "0" "0" "0" "0" "0" "0" "0"
             elif [ "$STATE" == "SELECT" ]; then
                 if [ "$MODE" == "0" ]; then
                     NEXT=$(( PRESET_IDX + 1 ))
                     [ "$NEXT" -ge "${#PRESETS[@]}" ] && NEXT=0
                     NEW_TIME=${PRESETS[$NEXT]}
                     WS "SELECT" "$NEW_TIME" "0" "0" "$NEW_ACT" "$NEXT" "0" "0" "0" "0" "0" "0" "0"
                 else
                     if [ "$P_EDIT_FOCUS" == "0" ]; then
                         WS "SELECT" "$SEC_SET" "0" "0" "$NEW_ACT" "$PRESET_IDX" "1" "0" "1" "$P_TOTAL" "$P_WORK_LEN" "$P_BREAK_LEN" "1"
                     elif [ "$P_EDIT_FOCUS" == "1" ]; then
                         WS "SELECT" "$SEC_SET" "0" "0" "$NEW_ACT" "$PRESET_IDX" "1" "0" "1" "$P_TOTAL" "$P_WORK_LEN" "$P_BREAK_LEN" "2"
                     else
                         WS "SELECT" "$SEC_SET" "0" "0" "$NEW_ACT" "$PRESET_IDX" "1" "0" "1" "$P_TOTAL" "$P_WORK_LEN" "$P_BREAK_LEN" "0"
                     fi
                 fi
             elif [ "$STATE" == "RUNNING" ] || [ "$STATE" == "PAUSED" ]; then
                 $0 click; exit 0
             fi
             ;;

        "middle")
             WS "RESET_ANIM" "0" "0" "0" "$NEW_ACT" "0" "0" "0" "0" "0" "0" "0" "0"
             ;;

        # --- CATCH-ALL: STANDARD TIMER (10s, 5m, 1h30m) ---
        *)
            INPUT="$1"
            SECONDS=0

            # Extract Hours (e.g. 1h)
            if [[ "$INPUT" =~ ([0-9]+)h ]]; then SECONDS=$((SECONDS + ${BASH_REMATCH[1]} * 3600)); fi
            # Extract Minutes (e.g. 5m)
            if [[ "$INPUT" =~ ([0-9]+)m ]]; then SECONDS=$((SECONDS + ${BASH_REMATCH[1]} * 60)); fi
            # Extract Seconds (e.g. 10s or just 300)
            if [[ "$INPUT" =~ ([0-9]+)s ]]; then
                SECONDS=$((SECONDS + ${BASH_REMATCH[1]}))
            elif [[ "$INPUT" =~ ^[0-9]+$ ]]; then
                # If it's a raw number and we haven't found h/m/s indicators, treat as seconds
                # But we must verify if 'h' or 'm' wasn't present to avoid double counting '1h' as '1'.
                if [[ ! "$INPUT" =~ [hm] ]]; then
                   SECONDS=$INPUT
                fi
            fi

            if [ "$SECONDS" -gt 0 ]; then
                WS "RUNNING" "$SECONDS" "$NOW" "0" "$NEW_ACT" "0" "0" "0" "0" "0" "0" "0" "0"
                trigger_update; exit 0
            fi
            ;;
    esac

    trigger_update; exit 0
fi

# -----------------------------------------------------------------------------
# SERVER LOOP (Efficient, Event-Driven)
# -----------------------------------------------------------------------------
if [ ! -f "$STATE_FILE" ]; then init_state; fi

# Create FIFO for instant updates if it doesn't exist
if [ ! -p "$PIPE_FILE" ]; then mkfifo "$PIPE_FILE"; fi

# Ensure the pipe stays open (avoid EOF loops)
exec 3<> "$PIPE_FILE"

while true; do
    read_state
    printf -v NOW '%(%s)T' -1

    TEXT=""
    ICON=""
    CLASS="$STATE"
    TOOLTIP=""

    case "$STATE" in
        "DISABLED")
            ICON="$ICON_DISABLED"
            CLASS="disabled"
            TOOLTIP="Timer Disabled\nLeft Click: Activate"
            echo "{\"text\": \"$ICON\", \"tooltip\": \"$TOOLTIP\", \"class\": \"$CLASS\"}"

            # OPTIMIZED: Block here indefinitely until FIFO receives data.
            # 0% CPU usage. Wakes instantly on click.
            read -n 1 _ <&3
            continue ;;

        "IDLE")
            ICON="$ICON_IDLE"
            TEXT="00:00"
            CLASS="idle"
            TOOLTIP="Timer Idle\nScroll Up: Standard Timer\nScroll Down: Pomodoro Mode\nLeft Click: Set Timer\nRight Click: Disable"

            if [ $(( NOW - LAST_ACT )) -gt "$INACTIVITY_LIMIT" ]; then
                WS "DISABLED" "0" "0" "0" "$NOW" "0" "0" "0" "0" "0" "0" "0" "0"
                trigger_update; continue
            fi
            ;;

        "SELECT")
            if [ "$MODE" == "0" ]; then
                ICON="$ICON_SELECT"
                TEXT="$(format_time $SEC_SET)"
                TOOLTIP="Timer Mode\nLeft Click: Start\nRight Click: Next Preset\nScroll: Adjust Time (± 1m)\nScroll &lt; 1m: Exit (Idle)"
            else
                ICON="$ICON_POMO_IDLE"
                if [ "$P_EDIT_FOCUS" == "1" ]; then
                    TEXT="${P_WORK_LEN}m | [${P_BREAK_LEN}]b | ${P_TOTAL}s"
                    TOOLTIP="Editing Break Time\nScroll: Change Break (± 1m)\nRight Click: Edit Sessions"
                elif [ "$P_EDIT_FOCUS" == "2" ]; then
                    TEXT="${P_WORK_LEN}m | ${P_BREAK_LEN}b | [${P_TOTAL}]s"
                    TOOLTIP="Editing Sessions\nScroll: Change Sessions (± 1)\nRight Click: Edit Minutes"
                else
                    TEXT="[${P_WORK_LEN}]m | ${P_BREAK_LEN}b | ${P_TOTAL}s"
                    TOOLTIP="Pomodoro Mode\nScroll: Adjust Minutes (± 1m)\nScroll &lt; 1m: Exit (Idle)\nRight Click: Edit Break Time"
                fi
            fi
            CLASS="select"

            if [ $(( NOW - LAST_ACT )) -gt "$INACTIVITY_LIMIT" ]; then
                WS "DISABLED" "0" "0" "0" "$NOW" "0" "0" "0" "0" "0" "0" "0" "0"
                trigger_update; continue
            fi
            ;;

        "POMO_MSG")
            if [ "$P_STAGE" == "0" ]; then TEXT="Work $P_CURRENT/$P_TOTAL"; ICON="$ICON_POMO_START"; else TEXT="Break Time"; ICON="$ICON_POMO_BREAK"; fi
            echo "{\"text\": \"$ICON $TEXT\", \"class\": \"pomo_msg\"}"
            # Short sleep for animation, can stay as sleep or be read -t
            sleep 1.5
            WS "RUNNING" "$SEC_SET" "$NOW" "0" "$NEW_ACT" "$PRESET_IDX" "$MODE" "$P_STAGE" "$P_CURRENT" "$P_TOTAL" "$P_WORK_LEN" "$P_BREAK_LEN" "$P_EDIT_FOCUS"
            continue ;;

        "RUNNING")
            ELAPSED=$(( NOW - START_TIME )); REM=$(( SEC_SET - ELAPSED ))
            if [ "$REM" -le 0 ]; then
                if [ "$MODE" == "0" ]; then
                    play_sound "$SOUND_TIMER_DONE"
                    notify-send -u critical -t 3500 -i clock "Timer" "Timer Finished!" &
                    WS "DONE" "$SEC_SET" "0" "0" "$NOW" "0" "0" "0" "0" "0" "0" "0" "0"
                else
                    if [ "$P_STAGE" == "0" ]; then
                        play_sound "$SOUND_BREAK_START"
                        notify-send -u normal -t 3500 -i tea "Pomodoro" "Work Session $P_CURRENT/$P_TOTAL Finished! Time for a Break." &
                        NEW_STAGE=1; NEW_SET=$(( P_BREAK_LEN * 60 ))
                        if [ "$POMO_AUTO_BREAK" = true ]; then
                            WS "POMO_MSG" "$NEW_SET" "$NOW" "0" "$NOW" "$PRESET_IDX" "1" "$NEW_STAGE" "$P_CURRENT" "$P_TOTAL" "$P_WORK_LEN" "$P_BREAK_LEN" "$P_EDIT_FOCUS"
                        else
                            WS "PAUSED" "$NEW_SET" "0" "$NEW_SET" "$NOW" "$PRESET_IDX" "1" "$NEW_STAGE" "$P_CURRENT" "$P_TOTAL" "$P_WORK_LEN" "$P_BREAK_LEN" "$P_EDIT_FOCUS"
                        fi
                    else
                        NEW_CURRENT=$(( P_CURRENT + 1 ))
                        if [ "$NEW_CURRENT" -gt "$P_TOTAL" ]; then
                            play_sound "$SOUND_COMPLETE"
                            notify-send -u critical -t 5000 -i trophy "Pomodoro" "All Sessions Completed!" &
                            WS "DONE" "0" "0" "0" "$NOW" "0" "1" "0" "$P_TOTAL" "$P_TOTAL" "0" "0" "0"
                        else
                            play_sound "$SOUND_WORK_START"
                            notify-send -u critical -t 3500 -i clock "Pomodoro" "Break Finished! Back to work." &
                            NEW_STAGE=0; NEW_SET=$(( P_WORK_LEN * 60 ))
                            if [ "$POMO_AUTO_WORK" = true ]; then
                                WS "POMO_MSG" "$NEW_SET" "$NOW" "0" "$NOW" "$PRESET_IDX" "1" "$NEW_STAGE" "$NEW_CURRENT" "$P_TOTAL" "$P_WORK_LEN" "$P_BREAK_LEN" "$P_EDIT_FOCUS"
                            else
                                WS "PAUSED" "$NEW_SET" "0" "$NEW_SET" "$NOW" "$PRESET_IDX" "1" "$NEW_STAGE" "$NEW_CURRENT" "$P_TOTAL" "$P_WORK_LEN" "$P_BREAK_LEN" "$P_EDIT_FOCUS"
                            fi
                        fi
                    fi
                fi
                trigger_update; continue
            fi
            if [ "$MODE" == "1" ]; then
                if [ "$P_STAGE" == "1" ]; then ICON="$ICON_POMO_BREAK"; CLASS="pomo_break"
                else
                    TOTAL_DUR=$(( P_WORK_LEN * 60 ))
                    if [ "$REM" -lt 30 ]; then ICON="$ICON_POMO_END"; CLASS="warning"
                    elif [ "$REM" -le $(( TOTAL_DUR / 2 )) ]; then ICON="$ICON_POMO_HALF"; CLASS="running"
                    else ICON="$ICON_POMO_START"; CLASS="running"; fi
                fi
                TOOLTIP="Pomodoro: $([ "$P_STAGE" == 0 ] && echo Work || echo Break) ($P_CURRENT/$P_TOTAL)\nLeft Click: Pause\nScroll: Adjust Time (± 1m)\nMiddle Click: Reset"
            else
                if [ "$REM" -le 30 ] && [ "$REM" -gt 27 ]; then ICON="$ICON_WARNING"; CLASS="warning"
                elif [ "$REM" -le 10 ]; then ICON="$ICON_WARNING"; CLASS="warning"
                else ICON="$ICON_RUNNING"; CLASS="running"; fi
                TOOLTIP="Timer Running\nLeft Click: Pause\nMiddle Click: Reset\nScroll: Adjust Time (± 1m)"
            fi
            TEXT="$(format_time $REM)"
            ;;

        "PAUSED")
            if [ "$MODE" == "1" ]; then ICON="$ICON_POMO_BREAK"; TOOLTIP="Pomodoro Paused\nLeft Click: Resume\nScroll: Adjust Time (± 1m)\nMiddle Click: Reset"
            else ICON="$ICON_PAUSE"; TOOLTIP="Timer Paused\nLeft Click: Resume\nScroll: Adjust Time (± 1m)\nMiddle Click: Reset"; fi
            TEXT="$(format_time $PAUSE_REM)"; CLASS="paused" ;;

        "DONE")
            if [ "$MODE" == "1" ]; then ICON="$ICON_POMO_DONE"; TOOLTIP="Pomodoro Complete"
            else ICON="$ICON_DONE"; TOOLTIP="Timer Finished"; fi
            TEXT="00:00"; CLASS="done"
            if [ $(( NOW - LAST_ACT )) -gt 5 ]; then WS "IDLE" "0" "0" "0" "$NOW" "0" "0" "0" "0" "0" "0" "0" "0"; trigger_update; continue; fi ;;

        "RESET_ANIM")
             echo "{\"text\": \"$ICON_RESET --:--\", \"class\": \"reset\", \"tooltip\": \"Resetting...\"}"
             sleep 0.2; WS "IDLE" "0" "0" "0" "$NOW" "0" "0" "0" "0" "0" "0" "0" "0"; continue ;;
    esac

    echo "{\"text\": \"$ICON $TEXT\", \"tooltip\": \"$TOOLTIP\", \"class\": \"$CLASS\"}"
    read -t 1 -n 1 _ <&3
done
