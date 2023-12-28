#!/usr/bin/env bash

msg(){
    echo
    echo "==> $*"
    echo
}

err(){
    echo 1>&2
    echo "==> $*" 1>&2
    echo 1>&2
}

arch="arm64"

defconfig_original="vendor/lahaina-qgki_defconfig"
defconfig_gcov="vendor/lahaina-qgki_gcov_defconfig"
defconfig_pgo="vendor/lahaina-qgki_pgo_defconfig"

mode="$1"
echo "Mode: $mode"
if [ "$mode" = "gcov" ]; then
    cp arch/arm64/configs/$defconfig_original arch/arm64/configs/$defconfig_gcov
    echo "CONFIG_DEBUG_KERNEL=y"     >> arch/arm64/configs/$defconfig_gcov
    echo "CONFIG_DEBUG_FS=y"         >> arch/arm64/configs/$defconfig_gcov
    echo "CONFIG_GCOV_KERNEL=y"      >> arch/arm64/configs/$defconfig_gcov
    echo "CONFIG_GCOV_PROFILE_ALL=y" >> arch/arm64/configs/$defconfig_gcov
    defconfig=$defconfig_gcov
elif [ "$mode" = "pgo" ]; then
    cp arch/arm64/configs/$defconfig_original arch/arm64/configs/$defconfig_pgo
    echo "CONFIG_PGO=y"              >> arch/arm64/configs/$defconfig_pgo
    defconfig=$defconfig_pgo
else
    defconfig=$defconfig_original
fi

arch_opts="ARCH=${arch} SUBARCH=${arch}"
export ARCH="$arch"
export SUBARCH="$arch"

export CROSS_COMPILE="aarch64-elf-"

msg "Generating defconfig from \`make $defconfig\`..."
if ! make O=out $arch_opts "$defconfig"; then
    err "Failed generating .config, make sure it is actually available in arch/${arch}/configs/ and is a valid defconfig file"
    exit 2
fi

msg "Begin building kernel..."

make O=out $arch_opts -j"$(nproc --all)" prepare

if ! make O=out $arch_opts -j"$(nproc --all)"; then
    err "Failed building kernel, probably the toolchain is not compatible with the kernel, or kernel source problem"
    exit 3
fi

msg "Packaging the kernel..."

rm -r out/ak3
cp -r ak3 out/

cp out/arch/"$arch"/boot/Image out/ak3/Image
cat out/arch/"$arch"/boot/dts/vendor/oplus/lemonadev/*.dtb > out/ak3/dtb
python mkdtboimg.py create out/ak3/dtbo.img out/arch/"$arch"/boot/dts/vendor/oplus/lemonadev/*.dtbo

cd out/ak3
zip -r9 lemonade-$(/bin/date -u '+%Y%m%d-%H%M').zip .

