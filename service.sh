#!/system/bin/sh
# SARA PRO Background Service v2.3
MODID="sara_log_pusher"
MODDIR="/data/adb/modules/$MODID"
CONF="$MODDIR/config.conf"
SCRIPT="$MODDIR/sara_log_pusher.sh"

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 15; done

while true; do
    if [ -f "$CONF" ]; then
        . "$CONF"
        LAST_RUN=${LAST_RUN:-0}
        CURRENT_TIME=$(date +%s)
        DIFF=$((CURRENT_TIME - LAST_RUN))
        
        # 27-hour interval
        if [ "$DIFF" -ge 97200 ] || [ "$CURRENT_TIME" -lt "$LAST_RUN" ]; then
            # Run and update timestamp on success
            if sh "$SCRIPT" --auto; then
                sed -i "s/LAST_RUN=.*/LAST_RUN=$CURRENT_TIME/" "$CONF" || echo "LAST_RUN=$CURRENT_TIME" >> "$CONF"
            fi
        fi
    fi
    sleep 900
done
