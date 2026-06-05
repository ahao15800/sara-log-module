#!/system/bin/sh
# Sara Log Pusher v2.0 (Module Edition)
MODDIR=${0%/*}
CONF="$MODDIR/config.conf"

# 加载配置
if [ -f "$CONF" ]; then
    GITHUB_TOKEN=$(grep "GITHUB_TOKEN=" "$CONF" | cut -d'"' -f2)
    REPO=$(grep "REPO=" "$CONF" | cut -d'"' -f2)
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="/data/local/tmp/sara_logs_$TIMESTAMP"
TARBALL="/data/local/tmp/sara_logs_$TIMESTAMP.tar.gz"

echo "[+] 启动系统诊断与日志推送..."

mkdir -p "$LOG_DIR"

# [核心诊断] 动态命名空间检查
echo "[+] 正在检查命名空间隔离状态..."
GLOBAL_NS=$(readlink /proc/1/ns/mnt)
MM_PID=$(pgrep -f com.tencent.mm | head -n 1)
if [ -n "$MM_PID" ]; then
    MM_NS=$(readlink /proc/$MM_PID/ns/mnt)
    echo "Global NS: $GLOBAL_NS" > "$LOG_DIR/namespace.log"
    echo "WeChat NS: $MM_NS" >> "$LOG_DIR/namespace.log"
    [ "$GLOBAL_NS" != "$MM_NS" ] && echo "STATUS: Isolated" >> "$LOG_DIR/namespace.log" || echo "STATUS: Shared" >> "$LOG_DIR/namespace.log"
fi

# [性能诊断] Binder IPC 瓶颈审计
echo "[+] 正在审计 Binder 事务..."
cat /sys/kernel/debug/binder/state > "$LOG_DIR/binder_state.log" 2>/dev/null
cat /sys/kernel/debug/binder/transactions > "$LOG_DIR/binder_transactions.log" 2>/dev/null

# [安全诊断] TEE & Keystore 健康检查
echo "[+] 正在检查 TEE 与 Keystore 状态..."
dumpsys android.security.keystore > "$LOG_DIR/keystore_health.log"
ls -la /data/adb/tricky_store/ > "$LOG_DIR/tricky_store_audit.log" 2>/dev/null

# [热管理] CPU 调度与频率限制检查
echo "[+] 正在采集热管理数据..."
cat /sys/class/thermal/thermal_zone*/temp > "$LOG_DIR/thermal_stats.log" 2>/dev/null

# 常规日志采集
dmesg > "$LOG_DIR/dmesg.log"
cat /proc/mounts > "$LOG_DIR/mounts.log"

# 打包
tar -czf "$TARBALL" -C "/data/local/tmp" "sara_logs_$TIMESTAMP"

# 上传
if [ -z "$GITHUB_TOKEN" ] || [ -z "$REPO" ]; then
    echo "[!] 错误: 未配置 GitHub Token 或 Repo 路径"
    exit 1
fi

CONTENT=$(base64 < "$TARBALL" | tr -d '\n')
FILE_PATH="logs/sara_logs_$TIMESTAMP.tar.gz"

RESPONSE=$(curl -s -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$REPO/contents/$FILE_PATH" \
  -d "{
    \"message\": \"Module Auto Upload: $TIMESTAMP\",
    \"content\": \"$CONTENT\"
  }")

if echo "$RESPONSE" | grep -q "\"sha\""; then
    echo "[+] 推送成功: $FILE_PATH"
    # 更新最后运行时间
    sed -i "s/LAST_RUN=.*/LAST_RUN=\"$(date +%s)\"/" "$CONF"
    rm -rf "$LOG_DIR" "$TARBALL"
else
    echo "[!] 推送失败"
    exit 1
fi
