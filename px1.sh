#!/bin/bash
rm -rf .repo/local_manifests
rm -rf device/advan/X1
rm -rf vendor/advan/X1

repo init -u https://github.com/PixelOS-AOSP/android_manifest.git -b seventeen --git-lfs --depth=1
git clone https://github.com/mibomboq/local_manifest.git -b 17 .repo/local_manifests
/opt/crave/resync.sh || repo sync

export BUILD_USERNAME=bombo
export BUILD_HOSTNAME=crave
export GOMAXPROCS=16 GOMEMLIMIT=42GiB GOGC=25 MALLOC_ARENA_MAX=4

# run this line after resync
   wget https://github.com/yaap-17-stone/build_soong/raw/f9c27b0b9298f6eeee9a850346e0a646c3eaeb87/cmd/soong_build/main.go && mv main.go build/soong/cmd/soong_build/

source build/envsetup.sh

# run
breakfast X1 userdebug

make installclean
m pixelos

echo "Upload to gofile will be started..."
if [ -f out/target/product/X1/Pixel*X1*.zip ]; then
    wget https://raw.githubusercontent.com/lordgaruda/GoFile-Upload/refs/heads/master/upload.sh
    chmod +x upload.sh ; ./upload.sh out/target/product/X1/Pixel*X1*.zip
fi
echo "hame"
