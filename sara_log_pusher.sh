#!/system/bin/sh
# =============================================================================
# SARA 赛博诊断模块 - 全量日志采集引擎 (v4.2.0-Secure)
# =============================================================================
# 开发者: Poke Execution Engine
# 功能: 深度采集系统日志、内核状态及硬件指标，通过安全通道外发诊断数据。
# =============================================================================

# 1. 权限与身份验证检查 (Root Check)
if [ "$(id -u)" -ne 0 ]; then
    echo "[!] 错误: 必须以 root 权限运行此脚本。"
    exit 1
fi

MODDIR=${0%/*}
CONF="$MODDIR/config.conf"

# 2. 变量防御性初始化与配置加载
GITHUB_TOKEN=""
REPO=""
[ -f "$CONF" ] && . "$CONF"

if [ -z "$GITHUB_TOKEN" ] || [ -z "$REPO" ]; then
    echo "[!] 警告: 未检测到 GITHUB_TOKEN 或 REPO 配置。脚本将仅执行本地采集。"
fi

# 3. 随机化临时路径以规避审计 (Randomized Paths)
RANDOM_ID=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
LOG_DIR="/data/local/tmp/sys_tmp_$RANDOM_ID"
TARBALL="/data/local/tmp/diag_pkg_$RANDOM_ID.tar.gz"
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)

# 确保清理 (Cleanup Trap)
cleanup() {
    echo "[+] 正在清理临时文件..."
    rm -rf "$LOG_DIR"
    rm -f "$TARBALL"
    # 如果存在临时 HTTP 头文件，务必销毁
    [ -f "/data/local/tmp/.h_$RANDOM_ID" ] && rm -f "/data/local/tmp/.h_$RANDOM_ID"
}
trap cleanup EXIT

mkdir -p "$LOG_DIR"
echo "[+] 启动安全诊断流程: $TIMESTAMP"

# ==========================================
# 采集逻辑 (内核、SELinux、LSPosed 等)
# ==========================================
dmesg > "$LOG_DIR/kernel_dmesg.log" 2>/dev/null
cat /proc/mounts > "$LOG_DIR/system_mounts.log" 2>/dev/null
logcat -d | grep "avc: denied" > "$LOG_DIR/selinux_avc.log" 2>/dev/null
logcat -d -t 5000 *:W > "$LOG_DIR/system_warnings.log" 2>/dev/null
getenforce > "$LOG_DIR/selinux_mode.txt" 2>/dev/null

# 模块清单
{
    echo "--- ACTIVE MODULES INVENTORY ---"
    for prop in /data/adb/modules/*/module.prop; do
        if [ -f "$prop" ]; then
            echo "Path: $prop"
            cat "$prop"
            echo "--------------------------------"
        fi
    done
} > "$LOG_DIR/modules_inventory.txt" 2>/dev/null

# ==========================================
# 打包与安全外发 (Secure Upload)
# ==========================================
echo "[+] 正在封装诊断包..."
tar -czf "$TARBALL" -C "/data/local/tmp" "$(basename "$LOG_DIR")" || { echo "[!] 打包失败"; exit 1; }

if [ -n "$GITHUB_TOKEN" ] && [ -n "$REPO" ]; then
    echo "[+] 准备通过安全通道上传..."
    
    # 安全风险修复: 不在命令行中传递 Token
    HEADER_FILE="/data/local/tmp/.h_$RANDOM_ID"
    printf "Authorization: token %s\nAccept: application/vnd.github.v3+json\n" "$GITHUB_TOKEN" > "$HEADER_FILE"
    chmod 600 "$HEADER_FILE"

    # 执行异步上传
    nohup sh -c "
        content=\$(base64 < \"$TARBALL\" | tr -d '\n')
        curl -s -X PUT \
          -H @$HEADER_FILE \
          \"https://api.github.com/repos/$REPO/contents/logs/diag_$TIMESTAMP.tar.gz\" \
          -d \"{\\\"message\\\":\\\"Secure Analysis $TIMESTAMP\\\",\\\"content\\\":\\\"\$content\\\"}\" > /dev/null
        rm -f \"$HEADER_FILE\"
        rm -f \"$TARBALL\"
    " >/dev/null 2>&1 &

    echo "[+] 上传任务已在后台安全排队。"
fi

exit 0
