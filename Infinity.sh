#!/bin/bash

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
# This token was retrieved from your previous log for continuous functionality.
DEVICE_CODE="X1"
BUILD_TARGET="Project Infinity X"
ANDROID_VERSION="17"

# SHELL CONFIGURATION
export TZ="Asia/Jakarta"
export BUILD_USERNAME=dooprjkt
export BUILD_HOSTNAME=crave

# =========================================================
# TELEGRAM FUNCTIONS
# =========================================================

# Function to safely format and send a text message to Telegram
send_telegram() {
  local chat_id="$1"
  local message="$2"
  local _TK="$TG_BOT_TOKEN"

  # 1. Escape characters required by MarkdownV2 that are NOT meant to be formatters.
  # We use a comprehensive escaping logic to ensure *bold* text works.
  local escaped_message=$(echo "$message" | sed \
    -e 's/\*/\*TEMP\*/g' \
    -e 's/_/\_TEMP\_/g' \
    -e 's/\[/\\[/g' \
    -e 's/\]/\\]/g' \
    -e 's/(/\\(/g' \
    -e 's/)/\\)/g' \
    -e 's/~/\\~/g' \
    -e 's/`/\`/g' \
    -e 's/>/\\>/g' \
    -e 's/#/\\#/g' \
    -e 's/+/\\+/g' \
    -e 's/-/\\-/g' \
    -e 's/=/\\=/g' \
    -e 's/|/\\|/g' \
    -e 's/{/\\{/g' \
    -e 's/}/\\}/g' \
    -e 's/\./\\./g' \
    -e 's/!/\\!/g')

  # 2. Revert the temporary placeholders for the actual formatting characters that are intended for bold/italic.
  local re_escaped_message=$(echo "$escaped_message" | sed \
    -e 's/\*TEMP\*/\*/g' \
    -e 's/\_TEMP\_/\_/g')
  
  # 3. URL encode special characters for transmission, including newlines.
  local encoded_message=$(echo "$re_escaped_message" | sed \
    -e 's/%/%25/g' \
    -e 's/&/%26/g' \
    -e 's/+/%2b/g' \
    -e 's/ /%20/g' \
    -e 's/\"/%22/g' \
    -e 's/'"'"'/%27/g' \
    -e 's/\n/%0A/g')
    
  echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] Sending message to Telegram (${chat_id})"
  # We must explicitly set parse_mode to MarkdownV2
  curl -s -X POST "https://api.telegram.org/bot${_TK}/sendMessage" \
    -d "chat_id=${chat_id}" \
    -d "text=${encoded_message}" \
    -d "parse_mode=MarkdownV2" \
    -d "disable_web_page_preview=true" > /dev/null
}

send_telegram_file() {

  local chat_id="$1"
  local file_path="$2"
  local caption="$3"
  local _TK="$TG_BOT_TOKEN"

  if [ ! -f "$file_path" ]; then
    echo "Error: File $file_path not found!"
    return 1
  fi

  echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] Sending document to Telegram (${chat_id})"

  curl -s -X POST "https://api.telegram.org/bot${_TK}/sendDocument" \
    -F "chat_id=${chat_id}" \
    -F "document=@${file_path}" \
    -F "caption=${caption}" \
    -F "parse_mode=MarkdownV2" > /dev/null
}

# Function to format total seconds into HH:MM:SS string
format_duration() {
    local T=$1
    local H=$((T/3600))
    local M=$(( (T%3600)/60 ))
    local S=$((T%60))
    printf "%02d hours, %02d minutes, %02d seconds" $H $M $S
}


# =========================================================
# BUILD LOGIC FUNCTION
# =========================================================

start_build_process() {

    # --- STEP 1: START TIMER AND SEND INITIAL NOTIFICATION ---
    START_TIME=$(date +%s)

    # Message for Build Started
    local initial_msg="⚙️ *ROM Build Started!*

    *ROM:* $BUILD_TARGET
    *Android:* $ANDROID_VERSION
    *Device:* $DEVICE_CODE
    *Start Time:* $(date '+%Y-%m-%d %H:%M:%S %Z')"
    send_telegram "$TG_BUILD_CHAT_ID" "$initial_msg"
    echo "Build Started at $(date '+%Y-%m-%d %H:%M:%S')"

    # =========================================================
    # ORIGINAL BUILD STEPS
    # =========================================================

    # Init Project Infinity X
    git config --global url."https://${GH_TOKEN}@github.com/".insteadOf "https://github.com/"
    repo init --depth=1 -u https://github.com/ProjectInfinity-X/manifest -b 17 -g default,-mips,-darwin,-notdefault

	# Clean
	rm -rf .repo/local_manifests
	git -C build/soong cherry-pick --abort 2>/dev/null || true
	
    # Resync sources
    /opt/crave/resync.sh
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --force-remove-dirty
    /opt/crave/resync.sh
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --force-remove-dirty
    /opt/crave/resync.sh

    # Clean up existing trees
    echo "Starting remove repositories..."
    rm -rf device/advan/X1 device/advan/X1-kernel
    rm -rf vendor/advan/X1
    rm -rf kernel/advan/X1
    rm -rf device/mediatek/sepolicy_vndr
    rm -rf hardware/mediatek hardware/dolby
    rm -rf vendor/mediatek/ims
    rm -rf vendor/infinity-priv/keys
    
    echo "Successfully deleted previous repositories."

    echo "Cloning device stuff..."
    # Device Trees
    git clone https://github.com/DooPrjkt/android_device_advan_X1 -b InfinityX-cnb device/advan/X1 --depth 1
    git clone https://github.com/DooPrjkt/android_device_advan_X1-kernel device/advan/X1-kernel
    git clone https://github.com/DooPrjkt/android_device_mediatek_sepolicy_vndr -b lineage-24.0 device/mediatek/sepolicy_vndr --depth 1
    git clone https://github.com/DooPrjkt/android_kernel_dummy kernel/advan/X1
    git clone https://github.com/DooPrjkt/android_vendor_advan_X1 -b lineage-24.0 vendor/advan/X1 --depth 1
    git clone https://github.com/DooPrjkt/android_hardware_mediatek -b lineage-24.0 hardware/mediatek --depth 1
    git clone https://github.com/DooPrjkt/android_vendor_mediatek_ims vendor/mediatek/ims --depth 1
    git clone https://github.com/Tanzanite-Prjkt/android_hardware_dolby hardware/dolby --depth 1
    git clone https://github.com/ProjectInfinity-X/vendor_infinity-priv_keys -b 17 vendor/infinity-priv/keys --depth 1

    echo "Tree sync complete."

    # Setup the build environment
    . build/envsetup.sh
    echo "Environment setup success."

    # Lunch target selection
    lunch infinity_X1-user
    echo "Lunch command executed."

    # Build ROM
    echo "========================="
    echo "Starting ROM Compilation..."
    echo "========================="

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
    trap 'kill $MEMMON_PID 2>/dev/null' EXIT

    m bacon -j$(nproc --all) 2>&1 | tee log.txt

    BUILD_STATUS=${PIPESTATUS[0]} # Capture exit code immediately

    # --- STEP 3: CALCULATE TIME AND SEND FINAL NOTIFICATION ---
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    local DURATION_FORMATTED=$(format_duration $DURATION)
    
    if [[ $BUILD_STATUS -eq 0 ]]; then
        local status_icon="✅"
        local status_text="Success"
	LOG_FILE="log.txt"
    else
        local status_icon="❌"
        local status_text="Failure (Exit Code: $BUILD_STATUS)"
	LOG_FILE="out/error.log"
    fi

    # Final Message with Android Version
    local final_msg="${status_icon} *Build Finished!*

    *ROM:* $BUILD_TARGET
    *Android:* $ANDROID_VERSION
    *Device:* $DEVICE_CODE
    *Duration:* $DURATION_FORMATTED
    *Status:* $status_text
    *THIS ROM HAS KERNELSU-NEXT PREBUILT!*"
    send_telegram "$TG_BUILD_CHAT_ID" "$final_msg"

    if [[ -f "$LOG_FILE" ]]; then
	send_telegram_file "$TG_BUILD_CHAT_ID" "$LOG_FILE"
    else
	send_telegram "$TG_BUILD_CHAT_ID" "⚠️ Warning: Log file ${LOG_FILE} not found."
    fi

    # Conditional Upload ROM
    if [[ $BUILD_STATUS -eq 0 ]]; then
        echo "Build successful. Starting upload script..."
        # Calls the go-up script
        rm -rf go-up*
        wget https://raw.githubusercontent.com/nekoshirro/tools-gofile/refs/heads/private/go-up
        chmod +x go-up
        ./go-up out/target/product/X1/*X1*.zip
    else
        echo "Build failed. Skipping upload."
    fi

    # Display any error logs
    echo "Here is your error"
    cat out/error.log
}

# =========================================================
# MAIN EXECUTION
# =========================================================

# Check required environment variables (optional but good practice)
start_build_process
