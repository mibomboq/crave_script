#!/bin/bash
rm -rf .repo/local_manifests

repo init -u https://github.com/Lunaris-AOSP/android -b 16.2 --git-lfs --depth=1
git clone https://github.com/mibomboq/local_manifest.git -b los .repo/local_manifests
/opt/crave/resync.sh || repo sync

export BUILD_USERNAME=random
export BUILD_HOSTNAME=kid

# Sign
https://github.com/Tsaritsa-Prjkt/android_vendor_lineage-priv_keys.git
cd vendor/lineage-priv/keys
./keys.sh

cd -

. b*/env*

# run
lunch lineage_X1-bp4a-user

m bacon

echo "Upload to gofile will be started..."
if [ -f out/target/product/X1/Lunaris-AOSP-X1*.zip ]; then
    wget https://raw.githubusercontent.com/lordgaruda/GoFile-Upload/refs/heads/master/upload.sh
    chmod +x upload.sh ; ./upload.sh out/target/product/X1/Lunaris-AOSP-X1*.zip
fi
echo "finish"
