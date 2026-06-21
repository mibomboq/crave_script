#!/bin/bash

# ==========================================
# ⚙️ Config
# ==========================================
START_TIME=$(date +%s)
LOG_FILE="build_X1_$(date +%Y%m%d_%H%M).log"
DEVICE="X1"

TELEGRAM_TOKEN="8082278726:AAFA8kcxYYzDYRuBWJenpetLpQgyKUBlQRw"
TELEGRAM_CHAT_ID="-1003265091665"

rm -f "/tmp/build_failed.lock"

# ==========================================
# 📝 Logging
# ==========================================
exec 3>&1 4>&2
exec 1> >(tee -a "$LOG_FILE") 2>&1

set -eE
set -o pipefail

# ==========================================
# 📨 Helper Functions
# ==========================================
send_tg_msg() {
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "parse_mode=HTML" \
        -d "text=$1" > /dev/null
}

get_elapsed() {
    local END=$(date +%s)
    local MINS=$(( (END - START_TIME) / 60 ))
    local HRS=$((MINS / 60))
    local REM=$((MINS % 60))
    if [ "$HRS" -gt 0 ]; then
        echo "${HRS}h ${REM}m"
    else
        echo "${MINS}m"
    fi
}

handle_error() {
    trap - ERR
    set +eE
    set +o pipefail
    local LINE="$1"

    exec 1>&3 2>&4
    sleep 1

    [ -f "/tmp/build_failed.lock" ] && exit 1
    touch "/tmp/build_failed.lock"

    echo "❌ Build failed on line $LINE!"

    local LOG_LINK=""
    if [ -f "$LOG_FILE" ]; then
        command -v gzip &>/dev/null && gzip -9 "$LOG_FILE" && LOG_FILE="${LOG_FILE}.gz"
        if command -v jq &>/dev/null; then
            local SERVER=$(curl -s https://api.gofile.io/servers | jq -r '.data.servers[0].name')
            if [ -n "$SERVER" ] && [ "$SERVER" != "null" ]; then
                local RES=$(curl -s -F "file=@${LOG_FILE}" "https://${SERVER}.gofile.io/contents/uploadfile")
                [ "$(echo "$RES" | jq -r '.status')" == "ok" ] && \
                    LOG_LINK=$(echo "$RES" | jq -r '.data.downloadPage')
            fi
        fi
    fi

    local ELAPSED=$(get_elapsed)
    local MSG="BUILD FAILED ❌%0A"
    MSG+="├─ 📱 <b>Device:</b> ${DEVICE}%0A"
    MSG+="├─ 💿 <b>ROM:</b> PixelOS%0A"
    MSG+="├─ ⏱️ <b>Time:</b> ${ELAPSED}%0A"
    MSG+="├─ ⚠️ <b>Error:</b> Line ${LINE}"
    if [ -n "$LOG_LINK" ]; then
        MSG+="%0A└─ 📄 <a href=\"${LOG_LINK}\">View Crash Log</a>"
    else
        MSG+="%0A└─ 💻 Check Crave Logs"
    fi

    send_tg_msg "$MSG"
    exit 1
}

trap 'handle_error $LINENO' ERR

# ==========================================
# 🚀 Start Notification
# ==========================================
send_tg_msg "BUILD STARTED ⏳%0A├─ 📱 <b>Device:</b> ${DEVICE}%0A├─ 💿 <b>ROM:</b> PixelOS%0A└─ 💻 <b>Host:</b> Crave"

# ==========================================
# 🔄 Sync
# ==========================================
echo "=========================================="
echo "🧹 Cleaning up old trees..."
rm -rf .repo/local_manifests
rm -rf device/advan/X1
rm -rf vendor/advan/X1
rm -rf vendor/prize/camera
rm -rf out/target/product/X1

echo "📄 Initializing repo..."
repo init --no-repo-verify --git-lfs \
    -u https://github.com/Kitauji-High-School/pixelos_manifest.git \
    -b sixteen-qpr2 \
    -g default,-mips,-darwin,-notdefault

echo "📄 Cloning local manifests..."
git clone https://github.com/mibomboq/local_manifest.git -b master .repo/local_manifests

echo "🔄 Syncing repos..."
/opt/crave/resync.sh || repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)

send_tg_msg "SYNC DONE ✅%0A├─ 📱 <b>Device:</b> ${DEVICE}%0A├─ ⏱️ <b>Elapsed:</b> $(get_elapsed)%0A└─ 🔨 Starting compilation..."

# ==========================================
# 🔨 Compile
# ==========================================
export BUILD_USERNAME=bombo
export BUILD_HOSTNAME=crave

set +eE
source build/envsetup.sh
breakfast X1 user
set -eE

make installclean

echo "=========================================="
echo "🔨 Compiling PixelOS for $DEVICE..."
echo "=========================================="
m pixelos

ELAPSED=$(get_elapsed)
echo "⏱️ Build done in $ELAPSED"

# ==========================================
# ☁️ Upload & Notify
# ==========================================
echo "=========================================="
echo "☁️ Preparing upload..."

if ! command -v jq &>/dev/null; then
    sudo apt-get install -y jq > /dev/null
fi

ROM_ZIP=$(ls -t out/target/product/X1/Pixel*X1*.zip 2>/dev/null | head -n 1 || true)

if [ -z "$ROM_ZIP" ] || [ ! -f "$ROM_ZIP" ]; then
    echo "❌ ROM zip not found!"
    handle_error $LINENO
fi

echo "✅ Found ROM: $(basename "$ROM_ZIP")"

SERVER=$(curl -s https://api.gofile.io/servers | jq -r '.data.servers[0].name')
if [ -z "$SERVER" ] || [ "$SERVER" == "null" ]; then
    echo "❌ Failed to get Gofile server!"
    handle_error $LINENO
fi

echo "⬆️ Uploading $(basename "$ROM_ZIP") to $SERVER..."
UPLOAD_RES=$(curl -s --retry 3 --connect-timeout 20 --max-time 1800 \
    -F "file=@${ROM_ZIP}" \
    "https://${SERVER}.gofile.io/contents/uploadfile")

STATUS=$(echo "$UPLOAD_RES" | jq -r '.status')
if [ "$STATUS" != "ok" ]; then
    echo "❌ Upload failed!"
    handle_error $LINENO
fi

DOWNLOAD_LINK=$(echo "$UPLOAD_RES" | jq -r '.data.downloadPage')
echo "✅ Upload done! Link: $DOWNLOAD_LINK"

# ==========================================
# 🎉 Success Notification
# ==========================================
exec 1>&3 2>&4
sleep 1

command -v gzip &>/dev/null && gzip -9 "$LOG_FILE" && LOG_FILE="${LOG_FILE}.gz"

LOG_LINK=""
if command -v jq &>/dev/null; then
    LOG_SERVER=$(curl -s https://api.gofile.io/servers | jq -r '.data.servers[0].name')
    if [ -n "$LOG_SERVER" ] && [ "$LOG_SERVER" != "null" ]; then
        LOG_RES=$(curl -s -F "token=$(echo "$UPLOAD_RES" | jq -r '.data.guestToken')" \
            -F "folderId=$(echo "$UPLOAD_RES" | jq -r '.data.parentFolder')" \
            -F "file=@${LOG_FILE}" \
            "https://${LOG_SERVER}.gofile.io/contents/uploadfile" || true)
        [ "$(echo "$LOG_RES" | jq -r '.status')" == "ok" ] && \
            LOG_LINK=$(echo "$LOG_RES" | jq -r '.data.downloadPage')
    fi
fi

SUCCESS_MSG="BUILD SUCCESSFUL 🚀%0A"
SUCCESS_MSG+="├─ 📱 <b>Device:</b> ${DEVICE}%0A"
SUCCESS_MSG+="├─ 💿 <b>ROM:</b> PixelOS%0A"
SUCCESS_MSG+="├─ ⏱️ <b>Time:</b> ${ELAPSED}%0A"
SUCCESS_MSG+="├─ 🔗 <a href=\"${DOWNLOAD_LINK}\">Download ROM</a>"
if [ -n "$LOG_LINK" ]; then
    SUCCESS_MSG+="%0A└─ 📄 <a href=\"${LOG_LINK}\">Build Log</a>"
fi

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "parse_mode=HTML" \
    -d "text=${SUCCESS_MSG}" > /dev/null

echo "✅ Done! Notification sent."
