#!/usr/bin/env bash
# build_continue.sh — continues from hyprlang (hyprutils already installed)
set -euo pipefail

SUDOPW="${1:?Usage: bash build_continue.sh <sudo_password>}"
JOBS=$(nproc)
INSTALL_PREFIX=/usr
LOG=~/build_all.log

exec >> "$LOG" 2>&1

export CC=gcc-14
export CXX=g++-14

echo ""
echo "[CONTINUE] Resuming build from hyprlang — $(date)"

build_cmake() {
    local name="$1" url="$2" tag="${3:-}"
    echo ""
    echo "[BUILD] $name..."
    cd ~
    rm -rf "$name"
    if [ -n "$tag" ]; then
        git clone --depth=1 --branch "$tag" "$url" "$name"
    else
        git clone --depth=1 "$url" "$name"
    fi
    cd "$name"
    [ -f ".gitmodules" ] && git submodule update --init --recursive
    # Patch C++26 native_handle (not in GCC14 stdlib on Ubuntu 24.04)
    find . -name '*.cpp' -o -name '*.hpp' | xargs grep -l 'native_handle' 2>/dev/null | while read f; do
        sed -i 's/fcntl(.*->.*native_handle().*FD_CLOEXEC.*);/\/\/ native_handle patched/' "$f"
        sed -i 's/fcntl(.*\.native_handle().*FD_CLOEXEC.*);/\/\/ native_handle patched/' "$f"
    done
    cmake --no-warn-unused-cli \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_C_COMPILER=gcc-14 \
        -DCMAKE_CXX_COMPILER=g++-14 \
        -S . -B build 2>&1 | tail -3
    cmake --build build --config Release -j$JOBS 2>&1 | tail -5
    echo "$SUDOPW" | sudo -S cmake --install build 2>/dev/null
    echo "$SUDOPW" | sudo -S ldconfig 2>/dev/null
    echo "[DONE] $name installed."
}

# ── hyprlang ──────────────────────────────────────────────────────────────────
build_cmake "hyprlang"            "https://github.com/hyprwm/hyprlang.git"

# ── hyprcursor ────────────────────────────────────────────────────────────────
build_cmake "hyprcursor"          "https://github.com/hyprwm/hyprcursor.git"

# ── hyprgraphics ──────────────────────────────────────────────────────────────
build_cmake "hyprgraphics"        "https://github.com/hyprwm/hyprgraphics.git"

# ── hyprwayland-scanner ───────────────────────────────────────────────────────
build_cmake "hyprwayland-scanner" "https://github.com/hyprwm/hyprwayland-scanner.git"

# ── Hyprland 0.54.0 ──────────────────────────────────────────────────────────
echo ""
echo "[BUILD] Hyprland 0.54.0..."
cd ~
rm -rf Hyprland
git clone --depth=1 --branch v0.54.0 https://github.com/hyprwm/Hyprland.git Hyprland
cd Hyprland
git submodule update --init --recursive
find . -name '*.cpp' -o -name '*.hpp' | xargs grep -l 'native_handle' 2>/dev/null | while read f; do
    sed -i 's/fcntl(.*native_handle.*FD_CLOEXEC.*);/\/\/ native_handle patched/' "$f"
done
cmake --no-warn-unused-cli \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
    -DCMAKE_C_COMPILER=gcc-14 \
    -DCMAKE_CXX_COMPILER=g++-14 \
    -S . -B build 2>&1 | tail -3
cmake --build build --config Release -j$JOBS 2>&1 | tail -5
echo "$SUDOPW" | sudo -S cmake --install build 2>/dev/null
echo "$SUDOPW" | sudo -S ldconfig 2>/dev/null
echo "[DONE] Hyprland 0.54.0 installed."

# ── xdg-desktop-portal-hyprland ──────────────────────────────────────────────
echo ""
echo "[BUILD] xdg-desktop-portal-hyprland..."
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
cmake --build build -j$JOBS 2>&1 | tail -5
echo "$SUDOPW" | sudo -S cmake --install build 2>/dev/null
echo "$SUDOPW" | sudo -S ldconfig 2>/dev/null
echo "[DONE] xdg-desktop-portal-hyprland installed."

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
echo "[VERIFY] Checking installations..."
for bin in Hyprland hyprctl hyprpm; do
    command -v $bin &>/dev/null && echo "  [OK] $bin: $(command -v $bin)" || echo "  [MISSING] $bin"
done
for lib in libhyprgraphics libhyprutils libhyprlang libhyprcursor; do
    ldconfig -p 2>/dev/null | grep -q $lib && echo "  [OK] $lib" || echo "  [MISSING] $lib"
done

echo ""
echo "========================================"
echo " ALL DONE: $(date)"
echo "========================================"
