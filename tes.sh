#!/bin/bash
rm -rf .repo/local_manifests
rm -rf device/advan/X1
rm -rf hardware/mediatek
rm -rf device/mediatek/sepolicy_vndr
rm -rf vendor/advan/X1


repo init -u https://github.com/Evolution-X/manifest -b bka --git-lfs --depth=1
git clone https://github.com/mibomboq/local_manifest.git -b main .repo/local_manifests
/opt/crave/resync.sh || repo sync

export BUILD_USERNAME=random
export BUILD_HOSTNAME=kid

# Sign
git clone https://github.com/Evolution-X/vendor_evolution-priv_keys-template vendor/evolution-priv/keys
cd vendor/evolution-priv/keys
./keys.sh

cd -

. build/envsetup.sh

# run
lunch lineage_X1-bp4a-user

make installclean
m evolution

echo "Upload to gofile will be started..."
if [ -f out/target/product/X1/EvolutionX-16.0*.zip ]; then
    wget https://raw.githubusercontent.com/lordgaruda/GoFile-Upload/refs/heads/master/upload.sh
    chmod +x upload.sh ; ./upload.sh out/target/product/X1/EvolutionX-16.0*.zip
fi
echo "finish"
