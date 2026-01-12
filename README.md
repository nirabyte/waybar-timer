# Waybar Timer Module

Flexible timer for Waybar with mouse controls and CLI commands.

![Preview](assets/preview.gif)

## Features

- Countdown Timer with precise time tracking
- Mouse controls and CLI commands for automation
- Preset system for quick duration selection
- Desktop notifications on timer completion
- Visual indicators for multiple timer states: disabled, idle, select, running, paused, done
- Tooltip messages with helpful hints 
- Low/No CPU usage

## Requirements

- Nerd Font installed (e.g., JetBrains Mono, Cascadia Code, etc.)
- Notification daemon (for desktop notifications e.g. dunst, libnotify, mako, etc)

## Installation

1. Copy the script to your desire directory:
   Example: `~/.config/waybar/scripts`

   ```bash
   mkdir -p ~/.config/waybar/scripts
   cp timer.sh ~/.config/waybar/scripts/ ~

   # Make it executable
   chmod +x ~/.config/waybar/scripts/timer.sh
   ```

2. Add to Waybar config (`~/.config/waybar/config.jsonc`):

   ```jsonc
   "custom/timer": {
       "exec": "~/.config/waybar/scripts/timer.sh",
       "return-type": "json",
       "interval": 1,
       "on-click": "~/.config/waybar/scripts/timer.sh click",
       "on-click-right": "~/.config/waybar/scripts/timer.sh right",
       "on-click-middle": "~/.config/waybar/scripts/timer.sh middle",
       "on-scroll-up": "~/.config/waybar/scripts/timer.sh up",
       "on-scroll-down": "~/.config/waybar/scripts/timer.sh down",
       "tooltip": true
   }
   ```

   > Note: Replace `...timer.sh` with the path where you placed the script.

3. Add to Waybar style (`~/.config/waybar/style.css`):

   <details>
   <summary><strong>Click to expand CSS styling</strong></summary>

   ```css
   #custom-timer {
     background-color: #1e1e2e;
     /*color: #cdd6f4;*/
     padding: 0 9px;
     font-size: 16;
     border-radius: 15px;
     font-family: "Doto";
     font-weight: 900;

     transition: all 0.2s ease;
   }

   /* --- STATE: DISABLED (00:00, Idle) --- */
   #custom-timer.disabled {
     background-color: transparent;
     color: #bfbfbf;
     opacity: 0.6;
     font-weight: normal;
     /*margin-top: 4;*/
     animation-duration: 1s;
     animation-timing-function: ease-in-out;
     animation-direction: alternate;
   }

   /* --- STATE: IDLE (Active but 00:00) --- */
   #custom-timer.idle {
     background-color: transparent;
     color: #bfbfbf;
     /*margin-top: 3;*/
   }

   /* --- STATE: SELECTION MODE --- */
   #custom-timer.select {
     background-color: #373948;
     color: #85b2fa;
     /*margin-top: 2;*/
   }

   /* --- STATE: RUNNING (Normal) --- */
   #custom-timer.running {
     background-color: transparent;
     color: #cccccc;
     /*margin-top: 2;*/
   }

   /* --- STATE: PAUSED --- */
   #custom-timer.paused {
     background-color: #404040;
     color: #f9e2af;
     /*margin-top: 2;*/

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
     /*margin-top: 2;*/
   }

   /* --- STATE: DONE --- */
   #custom-timer.done {
     background-color: #bfbfbf;
     color: #11111b;
     /*margin-top: 2;*/
   }

   /* --- STATE: RESET ANIMATION --- */
   #custom-timer.reset {
     color: #ff4d4d;
     background-color: transparent;
     /*margin-top: 4;*/
   }

   /* -----------------------------------------------------------------------------
    * KEYFRAMES: Red Color Fading
    * ----------------------------------------------------------------------------- */
   @keyframes red-alert {
     0% {
       color: #ff4d4d;
       opacity: 1;
     }
     100% {
       color: #ff4d4d;
       opacity: 0.8;
       text-shadow: none;
     }
   }
   ```

   </details>

## Alias (Optional)

For easier access, add this alias to your `~/.bashrc` or `~/.zshrc`:

```bash
alias timer='~/.config/waybar/scripts/timer.sh'
```

Then source your shell config:

```bash
source ~/.bashrc  # or source ~/.zshrc
```

Now use: `timer 10s`, `timer 5m`, etc.

## Usage

### Mouse Controls

| Action       | Behavior                              |
| ------------ | ------------------------------------- |
| Left Click   | Primary action (cycle through states) |
| Right Click  | Secondary action (presets/disable)    |
| Middle Click | Reset timer                           |
| Scroll Up    | Add 1 minute to timer                 |
| Scroll Down  | Subtract 1 minute from timer          |

### CLI Commands

Time setting (auto-start):

```bash
./timer.sh 10s        # 10 seconds
./timer.sh 5m         # 5 minutes
./timer.sh 1hr        # 1 hour
./timer.sh 1h30m      # 1 hour 30 minutes
./timer.sh 1hr20m2s   # 1 hour, 20 minutes, 2 seconds
./timer.sh 300        # 300 seconds
```

Mouse simulation:

```bash
./timer.sh click      # Left click
./timer.sh right      # Right click
./timer.sh middle     # Middle click (reset)
./timer.sh up         # Scroll up (+1 minute)
./timer.sh down       # Scroll down (-1 minute)
```                                                      

### Timer Presets 

Right-clicking in SELECT mode(shows plus icon in the timer) cycles through these presets: `1, 5, 10, 15, 20, 25, 30, 45, 60` minutes.

## Configuration

Edit the top of timer.sh to customize timer prests, scroll seconds, and inactiviity time:

```bash
# Time presets (in minutes)
PRESETS=(1 5 10 15 20 25 30 45 60)

# Scroll step (seconds)
SCROLL_STEP=60

# Inactivity timeout (seconds)
INACTIVITY_LIMIT=60

# Icons (Nerd Font symbols)
# ......
#.......
```

### File Locations

- State file: `/tmp/waybar_timer.json`
- PID file: `/tmp/waybar_timer.pid`

## State File Format

The state is stored as: `STATE|SECONDS_SET|START_TIME|PAUSE_REMAINING|LAST_ACTIVITY|PRESET_INDEX`

Example: `RUNNING|300|1703123456|0|1703123456|2`

## Notifications

![Notification](assets/notification.png)

When a timer completes, it sends a notification.

## Behavior Details

### Inactivity Handling

- Timer automatically disables after 60 seconds
- Timer stays active when running/paused

### Warning States

- 30-27 seconds remaining: Warning icon and styling
- ≤10 seconds remaining: Warning icon and styling

## Contributing

Submit issues or pull requests for improvements.
