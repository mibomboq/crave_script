#!/bin/bash
rm -rf .repo/local_manifests
rm -rf device/advan
rm -rf vendor/advan

repo init --depth=1 --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 17 -g default,-mips,-darwin,-notdefault
git clone https://github.com/mibomboq/local_manifest.git -b 17 .repo/local_manifests
/opt/crave/resync.sh || repo sync

export BUILD_USERNAME=random
export BUILD_HOSTNAME=kid

git clone https://github.com/DooPrjkt/android_6781_common.git vendor/infinity-priv/keys

. build/envsetup.sh

# run
lunch infinity_X1-userdebug

m bacon

echo "Upload to gofile will be started..."
if [ -f out/target/product/X1/Project*X1*.zip ]; then
    wget https://raw.githubusercontent.com/lordgaruda/GoFile-Upload/refs/heads/master/upload.sh
    chmod +x upload.sh ; ./upload.sh out/target/product/X1/Project*X1*.zip
fi
echo "finish"
