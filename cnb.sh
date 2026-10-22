#!/bin/bash

# Init & sync
repo init -u https://github.com/Evolution-X/manifest -b cnb --git-lfs --depth=1
rm -rf .repo/local_manifests
git clone https://github.com/mibomboq/local_manifest.git -b 17 .repo/local_manifests
/opt/crave/resync.sh || repo sync

export BUILD_USERNAME=random
export BUILD_HOSTNAME=kid

# Sign keys
if [ ! -d vendor/evolution-priv/keys ]; then
    git clone https://github.com/Evolution-X/vendor_evolution-priv_keys-template.git vendor/evolution-priv/keys
    (cd vendor/evolution-priv/keys && ./keys.sh)
fi

# Patch soong_build main.go (yaap-17-stone)
PATCH_URL="https://github.com/yaap-17-stone/build_soong/commit/f9c27b0b9298f6eeee9a850346e0a646c3eaeb87.patch"
wget -q -O soong.patch "$PATCH_URL" || exit 1
if (cd build/soong && git apply -R --check --include='cmd/soong_build/main.go' "$OLDPWD/soong.patch" 2>/dev/null); then
    echo "Soong patch sudah ke-apply, skip"
else
    (cd build/soong && git apply --3way --include='cmd/soong_build/main.go' "$OLDPWD/soong.patch") || { rm -f soong.patch; exit 1; }
fi
rm -f soong.patch

# Build
. build/envsetup.sh
lunch lineage_X1-cp2a-user
m evolution

# Upload
ZIP=$(ls -t out/target/product/X1/EvolutionX-17.0-*.zip 2>/dev/null | head -1)
if [ -n "$ZIP" ]; then
    echo "Upload to gofile will be started..."
    wget -q https://raw.githubusercontent.com/lordgaruda/GoFile-Upload/refs/heads/master/upload.sh
    chmod +x upload.sh && ./upload.sh "$ZIP"
fi
echo "Finish"
