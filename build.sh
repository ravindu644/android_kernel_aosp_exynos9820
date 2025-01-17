#!/bin/bash

#init submodules
git submodule init && git submodule update

#main variables
export MODEL=$1
export ARCH=arm64
export RDIR="$(pwd)"
export KBUILD_BUILD_USER="@ravindu644"

# Device configuration
declare -A DEVICES=(
    [beyond2lte]="exynos9820-beyond2lte_defconfig"
    [beyond1lte]="exynos9820-beyond1lte_defconfig"
    [beyond0lte]="exynos9820-beyond0lte_defconfig"
    [beyondx]="exynos9820-beyondx_defconfig"
)

# Set device-specific variables
if [[ -v DEVICES[$MODEL] ]]; then
    read KERNEL_DEFCONFIG <<< "${DEVICES[$MODEL]}"
    echo -e "\n[i] Building with ${KERNEL_DEFCONFIG}..\n"
else
    echo -e "\n[!] Unknown device: $MODEL, setting to beyond2lte\n"
    read KERNEL_DEFCONFIG <<< "${DEVICES[beyond2lte]}"
fi

#install requirements
sudo apt install libarchive-tools zstd -y

#init neutron-clang
if [ ! -d "${HOME}/toolchains/neutron-clang" ]; then
    echo -e "\n[INFO] Cloning Neutron-Clang Toolchain\n"
    mkdir -p "${HOME}/toolchains/neutron-clang"
    cd "${HOME}/toolchains/neutron-clang"
    curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman" && chmod +x antman
    bash antman -S && bash antman --patch=glibc
    cd "${RDIR}"
fi

#init arm gnu toolchain
if [ ! -d "${HOME}/toolchains/gcc" ]; then
    echo -e "\n[INFO] Cloning ARM GNU Toolchain\n"
    mkdir -p "${HOME}/toolchains/gcc"
    cd "${HOME}/toolchains/gcc"
    curl -LO "https://developer.arm.com/-/media/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz"
    tar -xf arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz
    cd "${RDIR}"
fi

#export toolchain paths
export BUILD_CROSS_COMPILE="${HOME}/toolchains/gcc/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-"
export BUILD_CC="${HOME}/toolchains/neutron-clang/bin/clang"

#output dir
if [ ! -d "${RDIR}/out" ]; then
    mkdir -p "${RDIR}/out"
fi

#build dir
if [ ! -d "${RDIR}/build" ]; then
    mkdir -p "${RDIR}/build"
else
    rm -rf "${RDIR}/build" && mkdir -p "${RDIR}/build"
fi

#build options
export ARGS="
-C $(pwd) \
O=$(pwd)/out \
-j$(nproc) \
ARCH=arm64 \
CROSS_COMPILE=${BUILD_CROSS_COMPILE} \
CC=${BUILD_CC} \
CLANG_TRIPLE=aarch64-linux-gnu- \
"

#build kernel image
build_kernel(){
    cd "${RDIR}"
    #make ${ARGS} clean && make ${ARGS} mrproper
    make ${ARGS} "${KERNEL_DEFCONFIG}"
    make ${ARGS} menuconfig
    make ${ARGS}|| exit 1
    cp ${RDIR}/out/arch/arm64/boot/Image* ${RDIR}/build
}

#build anykernel zip
build_anykernel3(){
    rm -f ${RDIR}/AnyKernel3/Image && cp ${RDIR}/build/Image ${RDIR}/AnyKernel3
    cd ${RDIR}/AnyKernel3 && zip -r "../build/KernelSU-Next-${MODEL}-anykernel3-AOSP.zip" * && cd ${RDIR}
    echo -e "\n[i] Build finished..!\n"
}

build_kernel
build_anykernel3
