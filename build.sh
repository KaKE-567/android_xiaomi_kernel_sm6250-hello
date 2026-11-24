#!/usr/bin/env bash
set -e

# Kernel Directory
KERNEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${KERNEL_DIR}/out"
DEFCONFIG="${1:-curtana_defconfig}"

# Toolchain paths
TC_ROOT="/workspaces/toolchains"
CLANG_DIR="${TC_ROOT}/clang-r353983c"
GCC_DIR="${TC_ROOT}/aarch64-linux-android-4.9"
GCC32_DIR="${TC_ROOT}/arm-linux-androideabi-4.9"

# Verify toolchains exist
if [ ! -d "${CLANG_DIR}" ] || [ ! -d "${GCC_DIR}" ] || [ ! -d "${GCC32_DIR}" ]; then
    echo "[-] Error: Toolchain directory missing in ${TC_ROOT}!"
    echo "    Clang: ${CLANG_DIR}"
    echo "    GCC 64: ${GCC_DIR}"
    echo "    GCC 32: ${GCC32_DIR}"
    exit 1
fi

# Environment Setup
export PATH="${CLANG_DIR}/bin:${GCC_DIR}/bin:${GCC32_DIR}/bin:${PATH}"
export ARCH=arm64
export SUBARCH=arm64
export CC=clang
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-android-
export CROSS_COMPILE_ARM32=arm-linux-androideabi-
export HOSTCFLAGS="-fcommon"
export HOSTCXXFLAGS="-fcommon"

# Build arguments passed to make
MAKE_ARGS=(
    O="${OUT_DIR}"
    ARCH="${ARCH}"
    SUBARCH="${SUBARCH}"
    CC="${CC}"
    CLANG_TRIPLE="${CLANG_TRIPLE}"
    CROSS_COMPILE="${CROSS_COMPILE}"
    CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32}"
    HOSTCFLAGS="${HOSTCFLAGS}"
    HOSTCXXFLAGS="${HOSTCXXFLAGS}"
)

BUILD_START=$(date +"%s")

echo "================================================"
echo " Starting Kernel Build"
echo " Defconfig: ${DEFCONFIG}"
echo " Clang:     $(${CLANG_DIR}/bin/clang --version | head -n 1)"
echo " GCC 64:    $(${GCC_DIR}/bin/aarch64-linux-android-gcc --version | head -n 2 | tail -n 1)"
echo " GCC 32:    $(${GCC32_DIR}/bin/arm-linux-androideabi-gcc --version | head -n 2 | tail -n 1)"
echo " Output:    ${OUT_DIR}"
echo "================================================"

case "$1" in
    clean)
        echo "[*] Cleaning output directory..."
        make "${MAKE_ARGS[@]}" clean mrproper
        rm -rf "${OUT_DIR}"
        echo "[+] Done."
        exit 0
        ;;
    menuconfig)
        make "${MAKE_ARGS[@]}" menuconfig
        exit 0
        ;;
    *)
        ;;
esac

mkdir -p "${OUT_DIR}"

# Generate configuration if not already configured or if defconfig requested
if [ ! -f "${OUT_DIR}/.config" ] || [ -n "$1" ]; then
    echo "[*] Generating config from ${DEFCONFIG}..."
    make "${MAKE_ARGS[@]}" "${DEFCONFIG}"
fi

# Compile Kernel
THREADS=$(nproc --all)
echo "[*] Compiling kernel using ${THREADS} threads..."
make "${MAKE_ARGS[@]}" -j"${THREADS}"

BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))

echo "================================================"
if [ -f "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb" ]; then
    echo "[+] Build successful!"
    echo "    Image: ${OUT_DIR}/arch/arm64/boot/Image.gz-dtb"
elif [ -f "${OUT_DIR}/arch/arm64/boot/Image.gz" ]; then
    echo "[+] Build successful!"
    echo "    Image: ${OUT_DIR}/arch/arm64/boot/Image.gz"
elif [ -f "${OUT_DIR}/vmlinux" ]; then
    echo "[+] Build successful!"
    echo "    vmlinux: ${OUT_DIR}/vmlinux"
else
    echo "[-] Build completed, but kernel image not found."
fi

if [ -f "${OUT_DIR}/arch/arm64/boot/dtbo.img" ]; then
    echo "    DTBO:  ${OUT_DIR}/arch/arm64/boot/dtbo.img"
fi

echo " Total build time: $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds."
echo "================================================"
