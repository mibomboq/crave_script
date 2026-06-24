#!/bin/bash
rm -rf .repo/local_manifests
rm -rf device/advan/X1
rm -rf vendor/advan/X1
rm -rf out/target/product/X1

repo init --no-repo-verify --git-lfs -u https://github.com/LineageOS/android.git -b lineage-24.0 -g default,-mips,-darwin,-notdefault
git clone https://github.com/mibomboq/local_manifest.git -b los .repo/local_manifests
/opt/crave/resync.sh || repo sync

export BUILD_USERNAME=bombo
export BUILD_HOSTNAME=crave

source build/envsetup.sh

# run
breakfast lineage_X1-userdebug

make installclean
m bacon

echo "Upload to gofile will be started..."
if [ -f out/target/product/X1/*X1*.zip ]; then
    wget https://raw.githubusercontent.com/lordgaruda/GoFile-Upload/refs/heads/master/upload.sh
    chmod +x upload.sh ; ./upload.sh out/target/product/X1/*X1*.zip
fi
echo "finish"
