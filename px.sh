#!/bin/bash
rm -rf prebuilts/clang/host/linux-x86
rm -rf .repo/local_manifests
rm -rf device/advan/X1
rm -rf vendor/advan/X1
rm -rf vendor/prize/camera
rm -rf out/soong/.bootstrap out/soong/build.custom_X1.ninja


repo init --no-repo-verify --git-lfs -u https://github.com/Kitauji-High-School/pixelos_manifest.git -b sixteen-qpr2 -g default,-mips,-darwin,-notdefault
git clone https://github.com/mibomboq/local_manifest.git -b master .repo/local_manifests
/opt/crave/resync.sh || repo sync

export BUILD_USERNAME=bombo
export BUILD_HOSTNAME=crave

source build/envsetup.sh
breakfast X1 user
m pixelos

echo "Upload to gofile will be started..."
if [ -f out/target/product/X1/PixelOS_X1*.zip ]; then
    wget https://raw.githubusercontent.com/lordgaruda/GoFile-Upload/refs/heads/master/upload.sh
    chmod +x upload.sh ; ./upload.sh out/target/product/X1/PixelOS_X1-16.2-*.zip
fi
echo "hame"
