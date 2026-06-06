#!/system/bin/sh
# =============================================================================
# SARA PRO Diagnostic Engine (v4.5.0)
# =============================================================================
MODID="sara_log_pusher"
MODDIR="/data/adb/modules/$MODID"
CONF="$MODDIR/config.conf"
BASELINE="/data/adb/modules/$MODID/baseline.log"

if [ "$(id -u)" -ne 0 ]; then exit 1; fi

[ -f "$CONF" ] && . "$CONF"

RANDOM_ID=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6)
LOG_DIR="/data/local/tmp/sara_logs_$RANDOM_ID"
TARBALL="/data/local/tmp/sara_diag_$RANDOM_ID.tar.gz"
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)

mkdir -p "$LOG_DIR"

# 1. CORE DIAGNOSTIC
dmesg | tail -n 500 > "$LOG_DIR/kernel.log"
getenforce > "$LOG_DIR/selinux.txt"
[ -d /data/adb/lspd ] && LSPD="OK" || LSPD="FAIL"
[ -d /sys/fs/susfs ] && SUSFS="OK" || SUSFS="FAIL"

# 2. BASELINE COMPARISON (Lightweight log-diff)
if [ -f "$BASELINE" ]; then
    grep "avc: denied" "$LOG_DIR/kernel.log" > "$LOG_DIR/current_denials.log"
    diff "$BASELINE" "$LOG_DIR/current_denials.log" > "$LOG_DIR/baseline_diff.txt"
else
    # Capture first-run baseline
    grep "avc: denied" "$LOG_DIR/kernel.log" > "$BASELINE"
fi

# 3. STRUCTURED REPORT (For WebUI Parsing)
{
    echo "SUSFS_STATUS=$SUSFS"
    echo "LSPD_STATUS=$LSPD"
    echo "SELINUX=$(cat "$LOG_DIR/selinux.txt")"
    echo "TIMESTAMP=$TIMESTAMP"
    echo "SUMMARY=Cyber Audit v4.5 completed"
    echo "FAULT_SIG=$(sha256sum "$LOG_DIR/kernel.log" | head -c 8)"
} > "$LOG_DIR/diagnosis_report.txt"

# 4. SECURE UPLOAD
tar -czf "$TARBALL" -C "/data/local/tmp" "$(basename "$LOG_DIR")"

if [ -n "$GITHUB_TOKEN" ] && [ -n "$REPO" ]; then
    HEADER_FILE="/data/local/tmp/.h_$RANDOM_ID"
    printf "Authorization: token %s\nAccept: application/vnd.github.v3+json\n" "$GITHUB_TOKEN" > "$HEADER_FILE"
    chmod 600 "$HEADER_FILE"

    # Capture HTTP code for WebUI feedback
    content=$(base64 < "$TARBALL" | tr -d '\n')
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
      -H @$HEADER_FILE \
      "https://api.github.com/repos/$REPO/contents/logs/pro_diag_$TIMESTAMP.tar.gz" \
      -d "{\"message\":\"SARA PRO Audit $TIMESTAMP\",\"content\":\"$content\"}")
    
    echo "$http_code" > /data/local/tmp/sara_upload_res.log
    rm -f "$HEADER_FILE"
fi

# 5. DEVICE PROFILE / HISTORY STUB
echo "$TIMESTAMP | SIG: $(sha256sum "$LOG_DIR/diagnosis_report.txt" | head -c 8) | SUSFS: $SUSFS" >> "$MODDIR/history.log"

exit 0
