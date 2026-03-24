#!/usr/bin/env bash
# build_all.sh — runs on M2 non-interactively
# Pass sudo password as first argument: bash ~/build_all.sh "yourpassword"
set -euo pipefail

SUDOPW="${1:?Usage: bash build_all.sh <sudo_password>}"
JOBS=$(nproc)
INSTALL_PREFIX=/usr
LOG=~/build_all.log

# Wrapper: run sudo non-interactively
S() { echo "$SUDOPW" | sudo -S "$@" 2>/dev/null; }

exec > >(tee "$LOG") 2>&1

echo "========================================"
echo " Hyprland Ecosystem Build — $(date)"
echo " Jobs: $JOBS  Prefix: $INSTALL_PREFIX"
echo "========================================"

# ── STEP 1: Dependencies ──────────────────────────────────────────────────────
echo ""
echo "[STEP 1] apt-get update..."
echo "$SUDOPW" | sudo -S apt-get update -qq 2>/dev/null
echo "[STEP 1] Installing build dependencies..."
echo "$SUDOPW" | sudo -S apt-get install -y \
    gcc-14 g++-14 \
    cmake ninja-build meson g++ clang pkg-config git \
    libpixman-1-dev libcairo2-dev libjpeg-dev libwebp-dev \
    libmagic-dev libpng-dev librsvg2-dev \
    libgles2-mesa-dev libgl-dev libdrm-dev libgbm-dev \
    libinput-dev libudev-dev libxkbcommon-dev libxkbcommon-x11-dev \
    libseat-dev libpam0g-dev libdisplay-info-dev \
    libpipewire-0.3-dev libspa-0.2-dev \
    libdbus-1-dev libsystemd-dev \
    libwayland-dev wayland-protocols libwayland-egl-backend-dev \
    libxcb1-dev libxcb-composite0-dev libxcb-damage0-dev \
    libxcb-dri3-dev libxcb-ewmh-dev libxcb-icccm4-dev \
    libxcb-present-dev libxcb-randr0-dev libxcb-render-util0-dev \
    libxcb-render0-dev libxcb-res0-dev libxcb-shm0-dev \
    libxcb-util-dev libxcb-xfixes0-dev libxcb-xinput-dev \
    libxcb-xkb-dev libxcb-xtest0-dev \
    libx11-dev libx11-xcb-dev libxcursor-dev libxcomposite-dev \
    libxdamage-dev libxext-dev libxfixes-dev libxi-dev \
    libxinerama-dev libxrandr-dev libxrender-dev libxtst-dev \
    xwayland glslang-tools spirv-tools libvulkan-dev \
    libsdbus-c++-dev libtomlplusplus-dev \
    2>&1 | grep -E "(Reading|Building|Setting|Processing|done\.|error)" | tail -5
echo "[STEP 1] Done."

# ── Set GCC 14 as default ─────────────────────────────────────────────────────
echo "[STEP 1b] Setting GCC 14 as default compiler..."
echo "$SUDOPW" | sudo -S update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 14 2>/dev/null
echo "$SUDOPW" | sudo -S update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 14 2>/dev/null
echo "$SUDOPW" | sudo -S update-alternatives --set gcc /usr/bin/gcc-14 2>/dev/null
echo "$SUDOPW" | sudo -S update-alternatives --set g++ /usr/bin/g++-14 2>/dev/null
export CC=gcc-14
export CXX=g++-14
g++ --version | head -1
echo "[STEP 1b] Done."

build_cmake() {
    local name="$1" url="$2" extra="${3:-}"
    echo ""
    echo "[BUILD] $name..."
    cd ~
    rm -rf "$name"
    git clone --depth=1 $extra "$url" "$name"
    cd "$name"
    if [ -f ".gitmodules" ]; then
        git submodule update --init --recursive
    fi
    # Patch C++26 native_handle if present (not in GCC14 stdlib on Ubuntu 24.04)
    find . -name '*.cpp' -o -name '*.hpp' | xargs grep -l 'native_handle' 2>/dev/null | while read f; do
        sed -i 's/fcntl(.*native_handle.*FD_CLOEXEC.*);/\/\/ native_handle patched out/' "$f"
    done
    cmake --no-warn-unused-cli \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_C_COMPILER=gcc-14 \
        -DCMAKE_CXX_COMPILER=g++-14 \
        -S . -B build 2>&1 | tail -3
    cmake --build build --config Release -j$JOBS 2>&1 | tail -3
    echo "$SUDOPW" | sudo -S cmake --install build 2>/dev/null
    echo "[DONE] $name installed."
}

# ── STEP 2-6: Hypr ecosystem deps ────────────────────────────────────────────
build_cmake "hyprutils"           "https://github.com/hyprwm/hyprutils.git"
build_cmake "hyprlang"            "https://github.com/hyprwm/hyprlang.git"
build_cmake "hyprcursor"          "https://github.com/hyprwm/hyprcursor.git"
build_cmake "hyprgraphics"        "https://github.com/hyprwm/hyprgraphics.git"
build_cmake "hyprwayland-scanner" "https://github.com/hyprwm/hyprwayland-scanner.git"

# ── STEP 7: Hyprland 0.54.0 ──────────────────────────────────────────────────
echo ""
echo "[STEP 7] Building Hyprland 0.54.0..."
cd ~
rm -rf Hyprland
git clone --depth=1 --branch v0.54.0 https://github.com/hyprwm/Hyprland.git
cd Hyprland
git submodule update --init --recursive
cmake --no-warn-unused-cli \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
    -DCMAKE_C_COMPILER=gcc-14 \
    -DCMAKE_CXX_COMPILER=g++-14 \
    -S . -B build 2>&1 | tail -3
cmake --build build --config Release -j$JOBS 2>&1 | tail -3
echo "$SUDOPW" | sudo -S cmake --install build 2>/dev/null
echo "[DONE] Hyprland 0.54.0 installed."

# ── STEP 8: xdg-desktop-portal-hyprland ──────────────────────────────────────
echo ""
echo "[STEP 8] Building xdg-desktop-portal-hyprland..."
cd ~
rm -rf xdg-desktop-portal-hyprland
git clone --depth=1 --recursive https://github.com/hyprwm/xdg-desktop-portal-hyprland.git
cd xdg-desktop-portal-hyprland
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=gcc-14 \
    -DCMAKE_CXX_COMPILER=g++-14 \
    -DCMAKE_INSTALL_LIBEXECDIR=/usr/lib \
    -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
    -B build 2>&1 | tail -3
cmake --build build -j$JOBS 2>&1 | tail -3
echo "$SUDOPW" | sudo -S cmake --install build 2>/dev/null
echo "[DONE] xdg-desktop-portal-hyprland installed."

# ── STEP 9: ldconfig + verify ─────────────────────────────────────────────────
echo ""
echo "[STEP 9] Running ldconfig..."
echo "$SUDOPW" | sudo -S ldconfig 2>/dev/null

echo ""
echo "[STEP 9] Verifying..."
for bin in Hyprland hyprctl hyprpm; do
    command -v $bin &>/dev/null && echo "  [OK] $bin" || echo "  [MISSING] $bin"
done
for lib in libhyprgraphics libhyprutils libhyprlang libhyprcursor; do
    ldconfig -p 2>/dev/null | grep -q $lib && echo "  [OK] $lib" || echo "  [MISSING] $lib"
done

echo ""
echo "========================================"
echo " ALL DONE: $(date)"
echo "========================================"
