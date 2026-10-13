#!/bin/bash

repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --git-lfs --depth=1
git clone https://github.com/mibomboq/local_manifest.git -b 17 .repo/local_manifests
/opt/crave/resync.sh || repo sync

export BUILD_USERNAME=random
export BUILD_HOSTNAME=kid

. build/envsetup.sh

# run
lunch X1-cp2a-userdebug

# resync
repo sync

# Patch soong_build main.go (yaap-17-stone), runs after resync
wget -q -O soong.patch "https://github.com/yaap-17-stone/build_soong/commit/f9c27b0b9298f6eeee9a850346e0a646c3eaeb87.patch" \
   && (cd build/soong && git apply --3way --include='cmd/soong_build/main.go' "$OLDPWD/soong.patch")
rc=$?
rm -f soong.patch
[ $rc -eq 0 ] || return 1

mka bacon

echo "Upload to gofile will be started..."
if [ -f out/target/product/X1/lineage-24.0*.zip ]; then
    wget https://raw.githubusercontent.com/lordgaruda/GoFile-Upload/refs/heads/master/upload.sh
    chmod +x upload.sh ; ./upload.sh out/target/product/X1/lineage-24.0*.zip
fi
echo "Finish"
