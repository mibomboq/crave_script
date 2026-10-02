#!/bin/bash

# =========================================================
# LOAD SECRETS (TG_BOT_TOKEN, TG_BUILD_CHAT_ID, GH_TOKEN)
# =========================================================
if [ -f "$HOME/.secrets" ]; then
    source "$HOME/.secrets"
else
    echo "File .secrets not found in $HOME"
fi

if [ -f "$(pwd)/.secrets" ]; then
    source "$(pwd)/.secrets"
else
    echo "File .secrets not found in $(pwd)"
fi

# =========================================================
# CONFIGURATION
# =========================================================
DEVICE_CODE="X1"
BUILD_TARGET="Project Infinity X"
ANDROID_VERSION="17"
LUNCH_TARGET="infinity_X1-user"

# Send progress updates every N seconds during compile (0 = off)
HEARTBEAT_INTERVAL=3600

# SHELL CONFIGURATION
export TZ="Asia/Jakarta"
export BUILD_USERNAME=dooprjkt
export BUILD_HOSTNAME=crave
export GOMAXPROCS=16 GOMEMLIMIT=42GiB GOGC=25 MALLOC_ARENA_MAX=4

# =========================================================
# HELPERS
# =========================================================

# Escape dynamic text to make it safe to use in parse_mode=HTML
esc() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# Short duration: 1h 05m 09s / 12m 30s / 45s
fmt_short() {
    local T=$1
    local H=$((T/3600))
    local M=$(( (T%3600)/60 ))
    local S=$((T%60))
    if [ "$H" -gt 0 ]; then
        printf "%dh %02dm %02ds" "$H" "$M" "$S"
    elif [ "$M" -gt 0 ]; then
        printf "%dm %02ds" "$M" "$S"
    else
        printf "%ds" "$S"
    fi
}

# Last ninja progress percentage from log.txt (blank if not already there)
build_progress() {
    [ -f log.txt ] || return 0
    tail -c 30000 log.txt 2>/dev/null | tr '\r' '\n' \
        | grep -aoE '\[ *[0-9]+% [0-9]+/[0-9]+' | tail -1 | sed 's/^\[ *//'
}

# =========================================================
# TELEGRAM FUNCTIONS (HTML mode)
# usage: send_telegram <chat_id> <html_message> [reply_markup_json]
# =========================================================
send_telegram() {
    local chat_id="$1"
    local message="$2"
    local markup="$3"
    local _TK="$TG_BOT_TOKEN"

    if [ -z "$_TK" ] || [ -z "$chat_id" ]; then
        echo "Telegram skip: TG_BOT_TOKEN / TG_BUILD_CHAT_ID is empty"
        return 0
    fi

    echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] Sending message to Telegram (${chat_id})"

    local args=(
        --data-urlencode "chat_id=${chat_id}"
        --data-urlencode "text=${message}"
        --data-urlencode "parse_mode=HTML"
        --data-urlencode "disable_web_page_preview=true"
    )
    [ -n "$markup" ] && args+=(--data-urlencode "reply_markup=${markup}")

    local resp
    resp=$(curl -s -X POST "https://api.telegram.org/bot${_TK}/sendMessage" "${args[@]}")

    if ! echo "$resp" | grep -q '"ok":true'; then
        echo "HTML send failed, retrying as plain text. Response: $resp"
        local plain
        plain=$(printf '%s' "$message" | sed \
            -e 's/<[^>]*>//g' \
            -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&amp;/\&/g')
        curl -s -X POST "https://api.telegram.org/bot${_TK}/sendMessage" \
            --data-urlencode "chat_id=${chat_id}" \
            --data-urlencode "text=${plain}" \
            --data-urlencode "disable_web_page_preview=true" > /dev/null
    fi
}

# usage: send_telegram_file <chat_id> <file> [html_caption]
send_telegram_file() {
    local chat_id="$1"
    local file_path="$2"
    local caption="$3"
    local _TK="$TG_BOT_TOKEN"

    if [ -z "$_TK" ] || [ -z "$chat_id" ]; then
        echo "Telegram skip: TG_BOT_TOKEN / TG_BUILD_CHAT_ID is empty"
        return 0
    fi

    if [ ! -f "$file_path" ]; then
        echo "Error: File $file_path not found!"
        return 1
    fi

    echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] Sending document to Telegram (${chat_id})"

    curl -s -X POST "https://api.telegram.org/bot${_TK}/sendDocument" \
        -F "chat_id=${chat_id}" \
        -F "document=@${file_path}" \
        -F "caption=${caption}" \
        -F "parse_mode=HTML" > /dev/null
}

# =========================================================
# NOTIFICATION TEMPLATES
# =========================================================

notify_start() {
    send_telegram "$TG_BUILD_CHAT_ID" "🚀 <b>ROM Build Started</b>

📦 <b>ROM:</b> $(esc "$BUILD_TARGET")
🤖 <b>Android:</b> $(esc "$ANDROID_VERSION")
📱 <b>Device:</b> <code>$(esc "$DEVICE_CODE")</code>
🎯 <b>Target:</b> <code>$(esc "$LUNCH_TARGET")</code>
🕒 <b>Start:</b> $(date '+%Y-%m-%d %H:%M:%S %Z')"
}

notify_progress() {
    send_telegram "$TG_BUILD_CHAT_ID" "$1"
}

notify_final() {
    # needs: BUILD_STATUS START_TIME BUILD_START BUILD_END
    # optional: ROM_ZIP UPLOAD_LINK
    local total=$((BUILD_END - START_TIME))
    local sync_t=$((BUILD_START - START_TIME))
    local build_t=$((BUILD_END - BUILD_START))

    local durations="⏱ <b>Duration</b>
├ Sync &amp; setup: $(fmt_short $sync_t)
├ Compile: $(fmt_short $build_t)
└ Total: $(fmt_short $total)"

    local head
    head="📦 <b>ROM:</b> $(esc "$BUILD_TARGET")
🤖 <b>Android:</b> $(esc "$ANDROID_VERSION")
📱 <b>Device:</b> <code>$(esc "$DEVICE_CODE")</code>
🎯 <b>Target:</b> <code>$(esc "$LUNCH_TARGET")</code>"

    if [[ $BUILD_STATUS -eq 0 ]]; then
        local file_block=""
        if [ -n "$ROM_ZIP" ] && [ -f "$ROM_ZIP" ]; then
            local size sha
            size=$(du -h "$ROM_ZIP" | cut -f1)
            sha=$(sha256sum "$ROM_ZIP" | cut -d' ' -f1)
            file_block="

📁 <b>File:</b> <code>$(esc "$(basename "$ROM_ZIP")")</code>
📏 <b>Size:</b> ${size}
🔐 <b>SHA256:</b> <code>${sha}</code>"
        fi

        local link_block=""
        local markup=""
        if [ -n "$UPLOAD_LINK" ]; then
            link_block="
🔗 <b>Download:</b> $(esc "$UPLOAD_LINK")"
            markup="{\"inline_keyboard\":[[{\"text\":\"⬇️ Download ROM\",\"url\":\"${UPLOAD_LINK}\"}]]}"
        fi

        send_telegram "$TG_BUILD_CHAT_ID" "✅ <b>Build Finished — Success</b>

${head}

${durations}${file_block}${link_block}" "$markup"
    else
        local err_tail=""
        [ -f out/error.log ] && err_tail=$(tail -n 15 out/error.log 2>/dev/null | cut -c1-200)
        [ -z "$err_tail" ] && [ -f log.txt ] && err_tail=$(tail -n 15 log.txt 2>/dev/null | tr '\r' '\n' | tail -n 15 | cut -c1-200)
        [ "${#err_tail}" -gt 1500 ] && err_tail=${err_tail: -1500}
        [ -z "$err_tail" ] && err_tail="(no error output found)"

        send_telegram "$TG_BUILD_CHAT_ID" "❌ <b>Build Failed</b> (exit code ${BUILD_STATUS})

${head}

${durations}

<b>Last errors:</b>
<pre>$(esc "$err_tail")</pre>"
    fi
}

# ===============================================================================
# CLONE HELPER
# usage: clone_repo <url> <branch|""> <dest> [depth]
# If the branch doesn't exist on the remote, fallback to the default branch.
# ======
clone_repo() {
    local url="$1"
    local branch="$2"
    local dest="$3"
    local depth="$4"
    local args=()

    [ -n "$depth" ] && args+=(--depth "$depth")

    if [ -n "$branch" ]; then
        if git clone "${args[@]}" -b "$branch" "$url" "$dest"; then
            return 0
        fi
        echo "WARNING: branch '$branch' not found for $dest, falling back to default branch"
        rm -rf "$dest"
    fi

    git clone "${args[@]}" "$url" "$dest"
}

# =========================================================
# BUILD LOGIC FUNCTION
# =========================================================

start_build_process() {

    START_TIME=$(date +%s)
    notify_start
    echo "Build Started at $(date '+%Y-%m-%d %H:%M:%S')"

    # =========================================================
    # SYNC SOURCE
    # =========================================================

    if [ -n "${GH_TOKEN:-}" ]; then
        git config --global url."https://${GH_TOKEN}@github.com/".insteadOf "https://github.com/"
    else
        echo "WARNING: GH_TOKEN is empty, private repo will fail to clone"
    fi

    repo init --depth=1 -u https://github.com/ProjectInfinity-X/manifest -b 17 -g default,-mips,-darwin,-notdefault

    /opt/crave/resync.sh
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --force-remove-dirty
    /opt/crave/resync.sh
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --force-remove-dirty
    /opt/crave/resync.sh

    # Patch soong_build main.go (yaap-17-stone), runs after resync
    echo "Patching soong_build main.go..."
    SOONG_MAIN_URL="https://github.com/yaap-17-stone/build_soong/raw/f9c27b0b9298f6eeee9a850346e0a646c3eaeb87/cmd/soong_build/main.go"
    if wget -q -O soong_main.go.tmp "$SOONG_MAIN_URL" && [ -s soong_main.go.tmp ]; then
        mv soong_main.go.tmp build/soong/cmd/soong_build/main.go
        echo "soong_build main.go patched."
    else
        rm -f soong_main.go.tmp
        echo "ERROR: failed to download soong_build patch, build aborted."
        notify_progress "❌ <b>Build Aborted</b>

Failed to download the soong_build patch, check the log."
        return 1
    fi

    notify_progress "🔄 <b>Source synced</b>
⏱ Took $(fmt_short $(( $(date +%s) - START_TIME )))
📥 Cloning device trees..."

    # =========================================================
    # CLEAN & CLONE TREES
    # =========================================================
    echo "Starting remove repositories..."
    rm -rf device/advan/X1 device/advan/X1-kernel
    rm -rf vendor/advan/X1
    rm -rf kernel/advan/X1
    rm -rf device/mediatek/sepolicy_vndr
    rm -rf hardware/mediatek hardware/dolby
    rm -rf vendor/mediatek/ims
    rm -rf device/prize/camera vendor/prize/camera
    rm -rf vendor/infinity-priv/keys
    echo "Successfully deleted previous repositories."

    echo "Cloning Private Keys"
    if [ -n "${GH_TOKEN:-}" ]; then
        clone_repo "https://x-access-token:${GH_TOKEN}@github.com/ProjectInfinity-X/vendor_infinity-priv_keys.git" \
            "17" vendor/infinity-priv/keys 1 \
            || echo "WARNING: clone private keys failed"
    else
        echo "GH_TOKEN unknown, skip clone private keys"
    fi

    echo "Cloning device stuff..."
    local CLONE_FAIL=0
    clone_repo https://github.com/DooPrjkt/android_device_advan_X1               "InfinityX-cnb" device/advan/X1 1               || CLONE_FAIL=1
    clone_repo https://github.com/DooPrjkt/android_device_advan_X1-kernel        ""              device/advan/X1-kernel ""       || CLONE_FAIL=1
    clone_repo https://github.com/DooPrjkt/android_device_mediatek_sepolicy_vndr "lineage-24.0"  device/mediatek/sepolicy_vndr 1 || CLONE_FAIL=1
    clone_repo https://github.com/DooPrjkt/android_kernel_dummy                  ""              kernel/advan/X1 ""              || CLONE_FAIL=1
    clone_repo https://github.com/DooPrjkt/android_vendor_advan_X1               "lineage-24.0"  vendor/advan/X1 1               || CLONE_FAIL=1
    clone_repo https://github.com/DooPrjkt/android_hardware_mediatek             "lineage-24.0"  hardware/mediatek 1             || CLONE_FAIL=1
    clone_repo https://github.com/DooPrjkt/android_vendor_mediatek_ims           ""              vendor/mediatek/ims 1           || CLONE_FAIL=1
    clone_repo https://github.com/Tanzanite-Prjkt/android_hardware_dolby         ""              hardware/dolby 1                || CLONE_FAIL=1
    clone_repo https://github.com/mibomboq/android_prize_pricamera.git          "17"            device/prize/camera ""          || CLONE_FAIL=1
    clone_repo https://github.com/mibomboq/android_vendor_common_pricam.git     ""              vendor/prize/camera ""          || CLONE_FAIL=1

    if [ "$CLONE_FAIL" -ne 0 ]; then
        echo "ERROR: a tree failed to clone, build aborted."
        notify_progress "❌ <b>Build Aborted</b>

There is a tree that failed to clone, check the log."
        return 1
    fi
    echo "Tree sync complete."

    # =========================================================
    # ENV & LUNCH
    # =========================================================
    . build/envsetup.sh
    echo "Environment setup success."

    if ! lunch "$LUNCH_TARGET"; then
        echo "ERROR: lunch $LUNCH_TARGET failed, build aborted."
        notify_progress "❌ <b>Build Aborted</b>

Lunch failed for device <code>$(esc "$DEVICE_CODE")</code>, check the log."
        return 1
    fi
    echo "Lunch command executed."

    # =========================================================
    # BUILD ROM
    # =========================================================
    echo "========================="
    echo "Starting ROM Compilation..."
    echo "========================="

    BUILD_START=$(date +%s)
    notify_progress "🔨 <b>Compiling started</b>
⏱ Setup took $(fmt_short $((BUILD_START - START_TIME)))
🎯 Target: <code>$(esc "$LUNCH_TARGET")</code>"

    # Memory monitor
    (
      while true; do
        echo "[memmon] === $(date +%T) ==="
        echo "[memmon] $(free -m | sed -n 2p)"
        echo "[memmon] cg.max=$(cat /sys/fs/cgroup/memory.max /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null | head -1) cg.peak=$(cat /sys/fs/cgroup/memory.peak /sys/fs/cgroup/memory/memory.max_usage_in_bytes 2>/dev/null | head -1)"
        ps -eo rss,comm --sort=-rss | head -4 | sed 's/^/[memmon] /'
        sleep 15
      done
    ) &
    MEMMON_PID=$!

    # Heartbeat progress to Telegram
    HB_PID=""
    if [ "${HEARTBEAT_INTERVAL:-0}" -gt 0 ]; then
        (
          while true; do
            sleep "$HEARTBEAT_INTERVAL"
            local_prog=$(build_progress)
            elapsed=$(( $(date +%s) - BUILD_START ))
            send_telegram "$TG_BUILD_CHAT_ID" "⏳ <b>Still building...</b>
⏱ Elapsed: $(fmt_short $elapsed)
📊 Progress: $(esc "${local_prog:-n/a}")"
          done
        ) &
        HB_PID=$!
    fi

    trap 'kill $MEMMON_PID $HB_PID 2>/dev/null' EXIT
    
   #clean
   make installclean
   
    m bacon -j$(nproc --all) 2>&1 | tee log.txt

    BUILD_STATUS=${PIPESTATUS[0]} # Capture exit code immediately
    BUILD_END=$(date +%s)

    # Force stop heartbeat
    [ -n "$HB_PID" ] && kill "$HB_PID" 2>/dev/null

    # =========================================================
    # UPLOAD (on success) + FINAL NOTIFICATION
    # =========================================================
    ROM_ZIP=""
    UPLOAD_LINK=""

    if [[ $BUILD_STATUS -eq 0 ]]; then
        echo "Build successful. Starting upload script..."
        ROM_ZIP=$(ls -t out/target/product/${DEVICE_CODE}/*${DEVICE_CODE}*.zip 2>/dev/null | head -1)

        if [ -n "$ROM_ZIP" ]; then
            notify_progress "⬆️ <b>Uploading ROM...</b>
📁 <code>$(esc "$(basename "$ROM_ZIP")")</code>"

            rm -rf go-up*
            wget https://raw.githubusercontent.com/nekoshirro/tools-gofile/refs/heads/private/go-up
            chmod +x go-up
            ./go-up "$ROM_ZIP" 2>&1 | tee go-up.log

            UPLOAD_LINK=$(sed 's/\x1b\[[0-9;]*m//g' go-up.log 2>/dev/null \
                | grep -aoE 'https?://[^ "<>]*gofile[^ "<>]*' | tail -1)
            [ -z "$UPLOAD_LINK" ] && UPLOAD_LINK=$(sed 's/\x1b\[[0-9;]*m//g' go-up.log 2>/dev/null \
                | grep -aoE 'https?://[^ "<>]+' | tail -1)
        else
            echo "WARNING: ROM zip not found in out/target/product/${DEVICE_CODE}/"
        fi
    else
        echo "Build failed. Skipping upload."
    fi

    notify_final

    # Send log
    local LOG_FILE="log.txt"
    local LOG_CAPTION="📄 Build log"
    if [[ $BUILD_STATUS -ne 0 ]] && [ -f out/error.log ]; then
        LOG_FILE="out/error.log"
        LOG_CAPTION="📄 Error log"
    fi

    if [[ -f "$LOG_FILE" ]]; then
        send_telegram_file "$TG_BUILD_CHAT_ID" "$LOG_FILE" "$LOG_CAPTION"
    else
        notify_progress "⚠️ Log file <code>$(esc "$LOG_FILE")</code> not found."
    fi

    # Show error log if present
    if [ -f out/error.log ]; then
        echo "Here is your error"
        cat out/error.log
    fi
}

# =========================================================
# TEST MODE: ./infinity-x1.sh tg-test
# =========================================================
run_tg_test() {
    START_TIME=$(( $(date +%s) - 5400 ))
    BUILD_START=$(( START_TIME + 600 ))
    BUILD_END=$(date +%s)

    notify_start
    notify_progress "🔨 <b>Compiling started</b>
⏱ Setup took 10m 00s
🎯 Target: <code>$(esc "$LUNCH_TARGET")</code>"
    notify_progress "⏳ <b>Still building...</b>
⏱ Elapsed: 1h 00m 00s
📊 Progress: 45% 12345/27000"

    local tmpzip="/tmp/tg-test-${DEVICE_CODE}.zip"
    head -c 1048576 /dev/zero > "$tmpzip"

    BUILD_STATUS=0
    ROM_ZIP="$tmpzip"
    UPLOAD_LINK="https://gofile.io/d/test123"
    notify_final

    BUILD_STATUS=1
    ROM_ZIP=""
    UPLOAD_LINK=""
    mkdir -p /tmp/tg-test-out && printf 'error: example <error> & test\nninja: build stopped\n' > /tmp/tg-test-out/error.log
    ( cd /tmp/tg-test-out && mkdir -p out && cp error.log out/error.log && notify_final )

    rm -f "$tmpzip"
    echo "tg-test done, check Telegram."
}

# =========================================================
# MAIN EXECUTION
# =========================================================
if [ "$1" = "tg-test" ]; then
    run_tg_test
else
    start_build_process
fi
