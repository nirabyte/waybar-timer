# Waybar Pomodoro Timer

A highly efficient, event-driven timer and pomodoro module for Waybar with mouse controls and CLI commands.

## Preview

https://github.com/user-attachments/assets/3bb65cbd-3923-4130-a2ee-8e5e86375802

## What's New

Check out the latest updates and improvements! See [Release Notes](https://github.com/nirabyte/waybar-timer/releases) for detailed changelog.

## Features

- **Dual Mode: Standard Timer and Pomodoro Mode** with customizable work/break cycles and sessions
- Mouse controls for all timer states (start, pause, edit, adjust)
- CLI arguments for terminal commands and shortcuts
- Desktop notifications and sound effects for all timer events
- Dynamic visual feedback with state-specific icons and colors in both modes.
- Customizable Presets for quick duration selection
- Tooltip messages with helpful hints
- Timer now persists even if Waybar is killed or restarted, and syncs across multiple instances
- Event-driven architecture with zero CPU usage, instant updates via named pipes
- RAM-based state storage to minimize SSD wear and disk IO

## Requirements

- Waybar (obviously)
- Notification daemon (for desktop notifications e.g. dunst, libnotify, mako, etc.)
- Nerd Font installed for icons (e.g., JetBrains Mono, Cascadia Code, Doto, etc.)
- PulseAudio or PipeWire (for sound playback via paplay)

## Installation

1. **Quick Installation**

   ```bash
   mkdir -p ~/.config/waybar/scripts ~/.config/waybar/sounds && \
   curl -L https://raw.githubusercontent.com/nirabyte/waybar-timer/main/timer.sh -o ~/.config/waybar/scripts/timer.sh && \
   curl -L https://raw.githubusercontent.com/nirabyte/waybar-timer/main/sounds/timer.mp3 -o ~/.config/waybar/sounds/timer.mp3 && \
   chmod +x ~/.config/waybar/scripts/timer.sh
   ```

   Or manually:

   ```bash
   mkdir -p ~/.config/waybar/scripts ~/.config/waybar/sounds
   # Save the script code to timer.sh
   chmod +x ~/.config/waybar/scripts/timer.sh
   # Add your timer.mp3 sound or your audio files to ~/.config/waybar/sounds/
   ```

2. **Add or update to waybar config (~/.config/waybar/config.jsonc)**

   **Note:** Do not add "interval" or "signal", as the script handles its own refresh loop.

   ```jsonc
   // place the module
   "modules-left": [
        "custom/timer"
    ],

   // define the module
   "custom/timer": {
       "exec": "~/.config/waybar/scripts/timer.sh",
       "return-type": "json",
       "format": "{}",
       "on-click": "~/.config/waybar/scripts/timer.sh click",
       "on-click-right": "~/.config/waybar/scripts/timer.sh right",
       "on-click-middle": "~/.config/waybar/scripts/timer.sh middle",
       "on-scroll-up": "~/.config/waybar/scripts/timer.sh down",  // previously up
       "on-scroll-down": "~/.config/waybar/scripts/timer.sh up",  // previously down
       "tooltip": true,
       "escape": true
   }
   ```

3. **Add to waybar style (~/.config/waybar/style.css)**

   Add these styles and customize colors, fonts, and animations to your preference.

   <details>
   <summary><strong>click to expand CSS styling</strong></summary>

   ```css
    /* Waybar Timer */
    #custom-timer {
        background-color: #1e1e2e;
        /*color: #cdd6f4;*/
        padding: 0 9px;
        font-size: 15px;
        border-radius: 15px;
        font-family: "Doto",  /* place your font here */
         /* Link for the above font https://fonts.google.com/specimen/Doto  */
        font-weight: 900;
        transition: all 0.2s ease;
    }

    /* --- STATE: DISABLED (00:00, Idle) --- */
    #custom-timer.disabled {
        background-color: transparent;
        color: #bfbfbf;
        opacity: 0.6;
        font-weight: normal;
        animation-duration: 1s;
        animation-timing-function: ease-in-out;
        animation-direction: alternate;
    }

    /* --- STATE: IDLE (Active but 00:00) --- */
    #custom-timer.idle {
        background-color: transparent;
        color: #bfbfbf;
    }

    /* --- STATE: SELECTION MODE --- */
    #custom-timer.select {
        background-color: #373948;
        color: #85b2fa;
    }

    /* --- STATE: RUNNING (Normal Timer & Pomodoro Work) --- */
    #custom-timer.running {
        background-color: transparent;
        color: #cccccc;
    }

    /* --- STATE: POMODORO BREAK (New) --- */
    #custom-timer.pomo_break {
        background-color: transparent;
        color: #f9e2af; /* Yellow/Gold to distinguish break from work */
    }

    /* --- STATE: POMODORO MESSAGE (New: "Work 1/4") --- */
    #custom-timer.pomo_msg {
        background-color: transparent;
        color: #cba6f7; /* Lavender/Purple for status messages */
    }

    /* --- STATE: PAUSED --- */
    #custom-timer.paused {
        background-color: #404040;
        color: #f9e2af;
        /*border: 1px solid #f9e2af; */
    }

    /* --- STATE: WARNING (< 10s or 30s alert) --- */
    #custom-timer.warning {
        background-color: transparent;
        animation-name: red-alert;
        animation-duration: 1s;
        animation-timing-function: ease-in-out;
        animation-iteration-count: infinite;
        animation-direction: alternate;
    }

    /* --- STATE: DONE --- */
    #custom-timer.done {
        background-color: #bfbfbf;
        color: #11111b;
    }

    /* --- STATE: RESET ANIMATION --- */
    #custom-timer.reset {
        color: #ff4d4d;
        background-color: transparent;
    }

    /* -----------------------------------------------------------------------------
    * KEYFRAMES: Red Color Fading
    * ----------------------------------------------------------------------------- */
    @keyframes red-alert {
        0% {
            color: #ff4d4d; /* Bright, visible Red */
            opacity: 1;
        }
        100% {
            color: #ff4d4d;
            opacity: 0.8; /* Fade cleanly to 80% transparency */
            text-shadow: none;
        }
    }

   ```

   </details>

4. **Setup sound effects (optional)**

   Create the sounds directory:

   ```bash
   mkdir -p ~/.config/waybar/sounds
   ```

   **Default setup (single sound file):**

   Add one sound file to this directory:
   - `timer.mp3` - plays for all timer events (completion, transitions, etc.)

   This repo includes a single `timer.mp3` sound file by default. You can download your own from:
   - [Freesound.org](https://freesound.org)
   - [Pixabay.com/sounds](https://pixabay.com/sound-effects)
   - [Zapsplat.com](https://www.zapsplat.com)

   **Advanced setup (multiple sound files):**

   You can customize the script to use different sounds for different events by editing the sound variables in `timer.sh`:

   ```bash
    SOUND_TIMER_DONE="${HOME}/.config/waybar/sounds/timer.mp3"
    SOUND_WORK_START="${HOME}/.config/waybar/sounds/timer.mp3"
    SOUND_BREAK_START="${HOME}/.config/waybar/sounds/timer.mp3"
    SOUND_BREAK_END="${HOME}/.config/waybar/sounds/timer.mp3"
    SOUND_COMPLETE="${HOME}/.config/waybar/sounds/timer.mp3"
   ```

   The script uses `paplay` (compatible with both PulseAudio and PipeWire) to play sounds.

5. **Restart your waybar**

- For Omarchy users:

  ```bash
  omarchy-restart-waybar
  # Or Toggle with Super+Shift+Space
  ```

- Or run:

  ```bash
  pkill waybar && nohup waybar &
  ```

## Alias (Optional)

For easier access, add this alias to your `~/.bashrc` or `~/.zshrc`:

```bash
alias timer='~/.config/waybar/scripts/timer.sh'
# or
alias pomo='~/.config/waybar/scripts/timer.sh pomo'
```

Then source your shell config:

```bash
source ~/.bashrc  # or source ~/.zshrc
```

Now use: `timer 20m5s`, `timer 1h30s`, `pomo 25m5m4s`, `pomo 40 10 2` etc.

## Usage

### Mouse Controls

| action       | state             | behavior                                |
| ------------ | ----------------- | --------------------------------------- |
| left click   | idle              | enter selection mode                    |
|              | select            | start timer                             |
|              | running           | pause timer                             |
|              | paused            | resume timer                            |
| right click  | idle              | disable module (hide)                   |
|              | select (standard) | cycle time presets (30s -> 1m -> 5m...) |
|              | select (pomodoro) | edit work ➡ edit break ➡ edit sessions  |
| middle click | any               | reset / cancel                          |
| scroll up    | select            | increase time (+1m)                     |
|              | running           | add 1 minute to current timer           |
| scroll down  | idle              | enter pomodoro mode                     |
|              | select            | decrease time (-1m)                     |
|              | running           | subtract 1 minute                       |

### CLI commands

**Time setting (auto-start):**

```bash
./timer.sh 10s        # 10 seconds
./timer.sh 5m         # 5 minutes
./timer.sh 1h         # 1 hour
./timer.sh 1h30m      # 1 hour 30 minutes
./timer.sh 1h20m2s    # 1 hour, 20 minutes, 2 seconds
./timer.sh 300        # 300 seconds
```

**Pomodoro:**

Syntax: `pomo [WORK] [BREAK] [SESSIONS]`

```bash
./timer.sh pomo            # Default: 25m Work, 5m Break, 4 Sessions
./timer.sh pomo 50 10 2    # 50m Work, 10m Break, 2 Sessions
./timer.sh pomo 25m 5b 4s  # Explicit syntax
```

**mouse simulation:**

```bash
./timer.sh click      # Left click (start/pause)
./timer.sh right      # Right click (presets/disable)
./timer.sh middle     # Middle click (reset)
./timer.sh up         # Add (+1 minute)
./timer.sh down       # Sub (-1 minute)
```

## How Pomodoro Mode works

1. Scroll down on the module (or run `./timer.sh pomo`)
2. The module enters pomodoro select mode
   - Text: `[25]m | 5b | 4s` (brackets indicate what scroll changes)
   - Right click to cycle focus between minutes, break, and sessions
3. Left click to start
4. Flow:
   - Work session 1 starts
   - Sound effect + notification when done
   - Break session 1 starts (auto-starts by default)
   - Repeats until all sessions are done

## Timer Presets

Right-clicking in SELECT mode (shows a plus sign in timer icon) cycles through these presets: 30s, 1m, 5m, 10m, 15m, 20m, 25m, 30m, 45m, 50m, 1h, 1h15m, 1h30m, 1h45m, 2h, 2h30m, 3h.

## Configuration

Edit the top of `timer.sh` to customize timer presets, scroll seconds, auto break/work, inactivity time, and sound effects:

```bash
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

# Icons (Nerd Font symbols)
# ......
#.......
```

## Technical Details (efficiency)

**State Management:** Stores state in `/dev/shm/waybar_timer.json`. This is RAM, not disk, saving SSD wear and ensuring top speed. The state persists across Waybar restarts and works seamlessly across multiple Waybar instances - all instances read/write to the same state file, keeping them in perfect sync.
**Event Loop:** Uses a Named Pipe (FIFO) at `/tmp/waybar_timer.fifo`.

- The script sits at `read -t 1 <> pipe`
- It waits 1 second OR until data is written to the pipe
- When you click, the controller writes to the pipe, causing the timer to wake up and update instantly

**Sound Playback:** Uses `paplay` for audio playback, which is compatible with both PulseAudio and PipeWire systems. Sounds play asynchronously without blocking the timer.

## File Locations

- State file: `/dev/shm/waybar_timer.json`
- FIFO pipe: `/tmp/waybar_timer.fifo`
- Sound effects: `~/.config/waybar/sounds/`

## State File Format

The state is stored as: `STATE|SECONDS_SET|START_TIME|PAUSE_REMAINING|LAST_ACTIVITY|PRESET_INDEX|MODE|P_STAGE|P_CURRENT|P_TOTAL|P_WORK_LEN|P_BREAK_LEN|P_EDIT_FOCUS`

Example: `RUNNING|300|1703123456|0|1703123456|2|0|0|0|0|0|0|0`

## Notifications & Sounds

When a timer or pomodoro session completes, the script sends a notification via `notify-send` and plays a sound effect via `paplay`.

**Default behavior (single sound file):**

All events play the same sound:

- **Standard timer finishes:** `timer.mp3`
- **Work session finishes:** `timer.mp3`
- **Break finishes, back to work:** `timer.mp3`
- **All sessions complete:** `timer.mp3`

**Advanced customization (multiple sound files):**

Edit the sound variables in `timer.sh` to use different sounds for different events:

- **Standard timer finishes:** `timer_done.mp3`
- **Work session finishes:** `break_start.mp3`
- **Break finishes, back to work:** `work_start.mp3`
- **All sessions complete:** `complete.mp3`

## Behavior Details

### Inactivity handling

- Timer automatically disables after 30 seconds of inactivity
- Timer stays active when running/paused

### Warning states

- 30-27 seconds remaining: warning icon and styling
- ≤10 seconds remaining: warning icon and styling with blink animation

## Uninstall

To remove the script run:

```bash
rm -f ~/.config/waybar/scripts/timer.sh
rm -rf ~/.config/waybar/sounds  # optional: remove sound files
```

## Contributing

Contributions are welcome and appreciated ❤️\
Please see [Contributing Guide](CONTRIBUTING.md) for detailed information on how to get started.

## License

This project is licensed under the [MIT License](LICENSE).
