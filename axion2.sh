#!/bin/bash
rm -rf .repo/local_manifests
rm -rf device/advan/X1
rm -rf vendor/advan/X1


repo init -u https://github.com/AxionAOSP/android.git -b lineage-23.2 --git-lfs --depth=1
git clone https://github.com/mibomboq/local_manifest.git -b axion .repo/local_manifests
/opt/crave/resync.sh || repo sync

export BUILD_USERNAME=bombo
export BUILD_HOSTNAME=crave

. build/envsetup.sh
axion X1 user full

make installclean

ax -b

echo "Upload to gofile will be started..."
if [ -f out/target/product/X1/axion-2.7-*.zip ]; then
    wget https://raw.githubusercontent.com/lordgaruda/GoFile-Upload/refs/heads/master/upload.sh
    chmod +x upload.sh ; ./upload.sh out/target/product/X1/axion-2.7-*.zip
fi
echo "finish"
