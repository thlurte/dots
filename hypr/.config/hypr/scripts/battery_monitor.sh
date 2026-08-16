#!/bin/bash

# Configuration
# -----------------------------------------------------
# Your internal monitor name (from hyprctl monitors)
MONITOR="eDP-1"
# Your external HDMI monitor (wired to Nvidia)
HDMI_MONITOR="HDMI-A-1"
# Heavy apps to kill on battery (Space separated)
APPS_TO_KILL="discord teams-for-linux steam"
# -----------------------------------------------------

# State tracking
last_state=""

while true; do
    # Check battery status (Discharging or Charging)
    # Uses wildcards to find BAT0 or BAT1 automatically
    battery_status=$(cat /sys/class/power_supply/BAT*/status | head -n 1)

    if [ "$battery_status" != "$last_state" ]; then
        if [ "$battery_status" == "Discharging" ]; then
            # ============================================
            # UNPLUGGED EVENTS (BATTERY MODE)
            # ============================================
            
            # 1. Notify User
            notify-send -u critical "Power Unplugged" "Switching to Power Saver (60Hz) & Disabling HDMI"

            # 2. Drop Refresh Rate to 60Hz
            hyprctl keyword monitor "$MONITOR,1920x1080@60,0x0,1"
            
            # 3. CRITICAL: Disable HDMI Port (Helps Nvidia GPU sleep)
            hyprctl keyword monitor "$HDMI_MONITOR, disable"

            # 4. Set CPU to Power Save (requires power-profiles-daemon)
            powerprofilesctl set power-saver

            # 5. Kill Heavy Apps
            for app in $APPS_TO_KILL; do
                pkill -f "$app"
            done
            
            # 6. Lower Brightness
            brightnessctl set 5%

        elif [ "$battery_status" == "Charging" ] || [ "$battery_status" == "Full" ]; then
            # ============================================
            # PLUGGED IN EVENTS (PERFORMANCE MODE)
            # ============================================
            
            # 1. Notify User
            notify-send -u low "Power Connected" "Performance Mode Enabled (Locked to 60Hz)"

            # 2. Keep Refresh Rate at 60Hz (Silent Mode)
            hyprctl keyword monitor "$MONITOR,1920x1080@60,0x0,1"
            
            # 3. Restore HDMI Monitor (So you can use external screens)
            hyprctl keyword monitor "$HDMI_MONITOR, 1920x1080@60, 1920x0, 1"

            # 4. Set CPU to Performance
            powerprofilesctl set performance
            
            # 5. Restore Brightness
            brightnessctl set 5%
        fi
        
        # Update state
        last_state="$battery_status"
    fi

    # Check every 5 seconds
    sleep 5
done
