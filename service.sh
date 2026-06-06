#!/system/bin/sh
# Sara Log Pusher Background Service v2.2
MODDIR=${0%/*}
CONF="$MODDIR/config.conf"
SCRIPT="$MODDIR/sara_log_pusher.sh"

# Wait for system boot and network connectivity
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 15
done

# Wait for network availability
while [ "$(getprop net.dns1)" = "" ]; do
    sleep 10
done

while true; do
    if [ -f "$CONF" ]; then
        . "$CONF"
        
        LAST_RUN=${LAST_RUN:-0}
        CURRENT_TIME=$(date +%s)
        
        # 27 hours interval = 97200 seconds
        DIFF=$((CURRENT_TIME - LAST_RUN))
        
        if [ "$DIFF" -ge 97200 ] || [ "$CURRENT_TIME" -lt "$LAST_RUN" ]; then
            sh "$SCRIPT" --auto
            # Update LAST_RUN on success or attempt
            NEW_TIME=$(date +%s)
            sed -i "s/LAST_RUN=.*/LAST_RUN=$NEW_TIME/" "$CONF" || echo "LAST_RUN=$NEW_TIME" >> "$CONF"
        fi
    fi
    
    sleep 900
done
