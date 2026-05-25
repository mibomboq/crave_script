#!/bin/bash
rm -rf prebuilts/clang/host/linux-x86
rm -rf .repo/local_manifests
rm -rf device/advan/X1
rm -rf vendor/advan/X1

repo init --no-repo-verify --git-lfs -u https://github.com/Kitauji-High-School/pixelos_manifest.git -b sixteen-qpr2 -g default,-mips,-darwin,-notdefault
git clone https://github.com/mibomboq/local_manifest.git -b master .repo/local_manifests
/opt/crave/resync.sh || repo sync

export BUILD_USERNAME=bombo
export BUILD_HOSTNAME=crave
export CUSTOM_MAINTAINER=Doo

source build/envsetup.sh
breakfast X1-user
m pixelos
