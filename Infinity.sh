#!/bin/bash
rm -rf .repo/local_manifests
rm -rf device/advan/X1
rm -rf vendor/advan/X1
rm -rf hardware/mediatek
rm -rf device/mediatek/sepolicy_vndr

repo init --depth=1 --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault
git clone https://github.com/mibomboq/local_manifest.git -b los .repo/local_manifests
/opt/crave/resync.sh || repo sync

export BUILD_USERNAME=random
export BUILD_HOSTNAME=kid

. build/envsetup.sh

# run
lunch infinity_X1-user

make installclean
m bacon

echo "Upload to gofile will be started..."
if [ -f out/target/product/X1/Project*X1*.zip ]; then
    wget https://raw.githubusercontent.com/lordgaruda/GoFile-Upload/refs/heads/master/upload.sh
    chmod +x upload.sh ; ./upload.sh out/target/product/X1/Project*X1*.zip
fi
echo "finish_bijh"
