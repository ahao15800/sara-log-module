#!/system/bin/sh
# Sara Log Pusher Background Service v2.1
MODDIR=${0%/*}
CONF="$MODDIR/config.conf"
SCRIPT="$MODDIR/sara_log_pusher.sh"

# Wait for system boot and network connectivity
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 15
done

# Wait for network availability (important for initial boot upload)
while [ "$(getprop net.dns1)" = "" ]; do
    sleep 10
done

while true; do
    if [ -f "$CONF" ]; then
        # Use sourcing for config to get LAST_RUN
        . "$CONF"
        
        # Default LAST_RUN to 0 if not set
        LAST_RUN=${LAST_RUN:-0}
        CURRENT_TIME=$(date +%s)
        
        # 27 hours interval = 97200 seconds
        # Handles system time drift: if CURRENT_TIME is less than LAST_RUN (time reset), trigger immediately.
        DIFF=$((CURRENT_TIME - LAST_RUN))
        
        if [ "$DIFF" -ge 97200 ] || [ "$CURRENT_TIME" -lt "$LAST_RUN" ]; then
            sh "$SCRIPT" --auto
        fi
    fi
    
    # Sleep 15 minutes between checks to save battery
    sleep 900
done
