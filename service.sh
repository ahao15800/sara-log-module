#!/system/bin/sh
# Sara Log Pusher 后台服务脚本
MODDIR=${0%/*}
CONF="$MODDIR/config.conf"
SCRIPT="$MODDIR/sara_log_pusher.sh"

# 等待系统启动完成
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 10
done

# 循环检查定时任务
while true; do
    # 读取配置
    if [ -f "$CONF" ]; then
        LAST_RUN=$(grep "LAST_RUN=" "$CONF" | cut -d'"' -f2)
        CURRENT_TIME=$(date +%s)
        # 27 小时 = 97200 秒
        DIFF=$((CURRENT_TIME - LAST_RUN))
        
        if [ "$DIFF" -ge 97200 ]; then
            # 执行推送
            sh "$SCRIPT" --auto
        fi
    fi
    # 每 5 分钟检查一次
    sleep 300
done
