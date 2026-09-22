#!/bin/bash

repo init -u https://github.com/Pixelify-AOSP/platform_manifest -b 17 --git-lfs --depth=1
git clone https://github.com/mibomboq/local_manifest.git -b 17 .repo/local_manifests
/opt/crave/resync.sh || repo sync

export BUILD_USERNAME=random
export BUILD_HOSTNAME=kid

. build/envsetup.sh

# run
lunch X1-cp2a-userdebug

# resync
repo sync

mka bacon

echo "Upload to gofile will be started..."
if [ -f out/target/product/X1/ASCP-v6.3-X1*.zip ]; then
    wget https://raw.githubusercontent.com/lordgaruda/GoFile-Upload/refs/heads/master/upload.sh
    chmod +x upload.sh ; ./upload.sh out/target/product/X1/ASCP-v6.3-X1*.zip
fi
echo "Finish"
