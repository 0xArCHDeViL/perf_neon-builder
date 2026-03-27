#!/bin/bash

# Environment setup
setup_environment() {
    echo "Setting up build environment..."
    local DEVICE_IMPORT="$1"
    local KERNELSU_SELECTOR="$2"
    local CLANG_SELECTOR="$3"

    # Maintainer info
    export KBUILD_BUILD_USER=archdevil
    export KBUILD_BUILD_HOST=evilzone
    export GIT_NAME="$KBUILD_BUILD_USER"
    export GIT_EMAIL="$KBUILD_BUILD_USER@$KBUILD_BUILD_HOST"

    # Clang selector
    if [[ "$CLANG_SELECTOR" == "--clang=LILIUM" ]]; then
        export CLANG_SELECTED="lilium"
        export CLANG_URL="https://github.com/liliumproject/clang/releases/download/20250912/lilium_clang-20250912.tar.gz"
    elif [[ "$CLANG_SELECTOR" == "--clang=ZYC" ]]; then
        export CLANG_SELECTED="zyc"
        export CLANG_URL="https://github.com/ZyCromerZ/Clang/releases/download/23.0.0git-20260130-release/Clang-23.0.0git-20260130.tar.gz"
    elif [[ "$CLANG_SELECTOR" == "--clang=KALEIDOSCOPE" ]]; then
        export CLANG_SELECTED="kaleidoscope"
        export CLANG_URL=""  # fetched dynamically in setup_toolchain
    else
        echo "Invalid clang selector. Use --clang=LILIUM, --clang=ZYC, or --clang=KALEIDOSCOPE."
        exit 1
    fi

    export CLANG_DIR=$PWD/clang
    export PATH="$CLANG_DIR/bin:/usr/bin:$PATH"

    # Device Settings
    export SELECTED_DEVICE="$DEVICE_IMPORT"
    if [[ "$DEVICE_IMPORT" == "sweet" ]]; then
        export MAIN_DEFCONFIG="arch/arm64/configs/vendor/sdmsteppe-perf_defconfig"
        export ACTUAL_MAIN_DEFCONFIG="vendor/sdmsteppe-perf_defconfig"
        export COMMON_DEFCONFIG="vendor/debugfs.config"
        export DEVICE_DEFCONFIG="vendor/sweet.config"
        export FEATURE_DEFCONFIG=""
    else
        echo "Invalid DEVICE_IMPORT. Only 'sweet' is supported."
        exit 1
    fi

    # KernelSU Settings
    if [[ "$KERNELSU_SELECTOR" == "--ksu=KSU_ZAKO" ]]; then
        export KSU_SELECTED="zako"
        export KSU_SETUP_URI="https://github.com/ReSukiSU/ReSukiSU/raw/refs/heads/main/kernel/setup.sh"
        export KSU_BRANCH="main"
        export KSU_GENERAL_PATCH="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/syscall_hook_patches.sh"
    elif [[ "$KERNELSU_SELECTOR" == "--ksu=KSU_ZAKO_SUSFS" ]]; then
        export KSU_SELECTED="zako_susfs"
        export KSU_SETUP_URI="https://github.com/ReSukiSU/ReSukiSU/raw/refs/heads/main/kernel/setup.sh"
        export KSU_BRANCH="main"
        export KSU_GENERAL_PATCH="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/susfs_inline_hook_patches.sh"
    elif [[ "$KERNELSU_SELECTOR" == "--ksu=NONE" ]]; then
        export KSU_SELECTED=""
        export KSU_SETUP_URI=""
        export KSU_BRANCH=""
        export KSU_GENERAL_PATCH=""
    else
        echo "Invalid KernelSU selector. Use --ksu=KSU_ZAKO, --ksu=KSU_ZAKO_SUSFS, or --ksu=NONE."
        exit 1
    fi

    export KERNEL_NAME="-perf-neon"
}

# Setup toolchain
setup_toolchain() {
    echo "Setting up clang toolchain: $CLANG_SELECTED..."
    if [ -d "$CLANG_DIR" ]; then
        echo "Local clang dir found, using it."
        return
    fi

    mkdir -p "$CLANG_DIR"

    if [[ "$CLANG_SELECTED" == "kaleidoscope" ]]; then
        echo "Fetching Kaleidoscope latest link..."
        CLANG_URL=$(curl -fsSL "https://raw.githubusercontent.com/PurrrsLitterbox/LLVM-stable/refs/heads/main/latestlink.txt")
        if [[ -z "$CLANG_URL" ]]; then
            echo "Failed to fetch Kaleidoscope clang URL."
            exit 1
        fi
    fi

    echo "Downloading clang from: $CLANG_URL"
    wget -qO /tmp/clang.tar.gz "$CLANG_URL"
    tar -xf /tmp/clang.tar.gz -C "$CLANG_DIR" --strip-components=1
    rm -f /tmp/clang.tar.gz
}

# Setup device-specific patches
setup_specific() {
    echo "Applying device specific patches for $SELECTED_DEVICE..."

    # SUSFS kernel patch (only for zako_susfs)
    if [[ "$KSU_SELECTED" == "zako_susfs" ]]; then
        export SUSFS_PATCH="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/Patch/susfs_patch_to_4.14.patch"
        echo "Applying SUSFS patch..."
        wget -qO- $SUSFS_PATCH | patch -s -p1 --fuzz=5
    fi
}

# Setup KernelSU
setup_ksu() {
    echo "Setting up KernelSU..."
    if [[ "$KSU_SELECTED" == "zako" ]]; then
        curl -LSs $KSU_SETUP_URI | bash -s $KSU_BRANCH
        curl -LSs $KSU_GENERAL_PATCH | bash
        echo "CONFIG_KSU=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_MULTI_MANAGER_SUPPORT=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KPM=n" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_MANUAL_HOOK=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS=n" >> $MAIN_DEFCONFIG
        echo "CONFIG_HAVE_SYSCALL_TRACEPOINTS=y" >> $MAIN_DEFCONFIG
    elif [[ "$KSU_SELECTED" == "zako_susfs" ]]; then
        curl -LSs $KSU_SETUP_URI | bash -s $KSU_BRANCH
        curl -LSs $KSU_GENERAL_PATCH | bash
        echo "CONFIG_KSU=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_MULTI_MANAGER_SUPPORT=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KPM=n" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_MANUAL_HOOK=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_SUS_MAP=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_HAVE_SYSCALL_TRACEPOINTS=y" >> $MAIN_DEFCONFIG
    else
        echo "No KernelSU to set up."
    fi
}

# Compile kernel
compile_kernel() {
    echo "Starting kernel compilation..."
    make -j$(nproc --all) \
        O=out \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        AS=llvm-as \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CLANG_TRIPLE=aarch64-linux-gnu-
}

# Main
main() {
    echo "Validating input arguments..."
    if [ $# -ne 3 ]; then
        echo "Usage: $0 <DEVICE_IMPORT> <KERNELSU_SELECTOR> <CLANG_SELECTOR>"
        echo "Example: $0 sweet --ksu=KSU_ZAKO_SUSFS --clang=LILIUM"
        exit 1
    fi
    setup_environment "$1" "$2" "$3"
    setup_toolchain
    setup_specific
    setup_ksu
    setup_precompile
    compile_kernel
}

main "$1" "$2" "$3"
