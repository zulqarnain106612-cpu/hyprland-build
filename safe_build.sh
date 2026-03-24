#!/usr/bin/env bash
# safe_build.sh — installs Hyprland ecosystem to /opt/hypr (never touches system libs)
# Usage: bash ~/safe_build.sh "password"

SUDOPW="${1:?Usage: bash safe_build.sh <password>}"
PREFIX=/opt/hypr
JOBS=$(nproc)
CMAKE=/usr/local/bin/cmake
LOG=~/safe_build.log

exec > >(tee "$LOG") 2>&1

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib/x86_64-linux-gnu/pkgconfig:$PREFIX/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"
export LD_LIBRARY_PATH="$PREFIX/lib:$PREFIX/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu"
export PATH="$PREFIX/bin:/usr/local/bin:$PATH"
export CC=gcc-14
export CXX=g++-14

echo "PREFIX=$PREFIX"
echo "Started: $(date)"

# Setup prefix
echo "$SUDOPW" | sudo -S mkdir -p "$PREFIX"
echo "$SUDOPW" | sudo -S chown zulqarnain:zulqarnain "$PREFIX"
mkdir -p "$PREFIX/lib/pkgconfig" "$PREFIX/include" "$PREFIX/bin"

build_cmake() {
    local name="$1" url="$2" tag="${3:-}"
    echo ""
    echo "[BUILD] $name..."
    cd ~
    rm -rf "$name"
    [ -n "$tag" ] && git clone --depth=1 --branch "$tag" "$url" "$name" \
                  || git clone --depth=1 "$url" "$name"
    cd "$name"
    [ -f ".gitmodules" ] && git submodule update --init --recursive
    rm -rf build
    $CMAKE --no-warn-unused-cli \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_C_COMPILER=gcc-14 \
        -DCMAKE_CXX_COMPILER=g++-14 \
        -S . -B build 2>&1 | tail -3
    $CMAKE --build build -j$JOBS 2>&1 | tail -3
    $CMAKE --install build 2>/dev/null
    echo "$SUDOPW" | sudo -S ldconfig 2>/dev/null
    echo "[DONE] $name"
}

build_meson() {
    local name="$1" url="$2" tag="${3:-}" extra="${4:-}"
    echo ""
    echo "[BUILD] $name..."
    cd ~
    rm -rf "$name"
    [ -n "$tag" ] && git clone --depth=1 --branch "$tag" "$url" "$name" \
                  || git clone --depth=1 "$url" "$name"
    cd "$name"
    rm -rf build
    meson setup build --prefix="$PREFIX" $extra 2>&1 | tail -3
    ninja -C build -j$JOBS 2>&1 | tail -3
    ninja -C build install 2>/dev/null
    echo "$SUDOPW" | sudo -S ldconfig 2>/dev/null
    echo "[DONE] $name"
}

# ── Already installed to /usr — reinstall to /opt/hypr ───────────────────────
echo ""
echo "[PHASE 1] Reinstalling hypr libs to $PREFIX..."

# hyprutils (already built, just reinstall to new prefix)
cd ~/hyprutils
rm -rf build
$CMAKE --no-warn-unused-cli -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_C_COMPILER=gcc-14 -DCMAKE_CXX_COMPILER=g++-14 -S . -B build 2>&1 | tail -2
$CMAKE --build build -j$JOBS 2>&1 | tail -2
$CMAKE --install build 2>/dev/null
echo "[DONE] hyprutils -> $PREFIX"

# hyprlang
cd ~/hyprlang
rm -rf build
$CMAKE --no-warn-unused-cli -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_C_COMPILER=gcc-14 -DCMAKE_CXX_COMPILER=g++-14 -S . -B build 2>&1 | tail -2
$CMAKE --build build -j$JOBS 2>&1 | tail -2
$CMAKE --install build 2>/dev/null
echo "[DONE] hyprlang -> $PREFIX"

# hyprcursor
cd ~/hyprcursor
rm -rf build
$CMAKE --no-warn-unused-cli -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_C_COMPILER=gcc-14 -DCMAKE_CXX_COMPILER=g++-14 -S . -B build 2>&1 | tail -2
$CMAKE --build build -j$JOBS 2>&1 | tail -2
$CMAKE --install build 2>/dev/null
echo "[DONE] hyprcursor -> $PREFIX"

# hyprgraphics
cd ~/hyprgraphics
rm -rf build
$CMAKE --no-warn-unused-cli -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_C_COMPILER=gcc-14 -DCMAKE_CXX_COMPILER=g++-14 -S . -B build 2>&1 | tail -2
$CMAKE --build build -j$JOBS 2>&1 | tail -2
$CMAKE --install build 2>/dev/null
echo "[DONE] hyprgraphics -> $PREFIX"

# hyprwayland-scanner
cd ~/hyprwayland-scanner
rm -rf build
$CMAKE --no-warn-unused-cli -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_C_COMPILER=gcc-14 -DCMAKE_CXX_COMPILER=g++-14 -S . -B build 2>&1 | tail -2
$CMAKE --build build -j$JOBS 2>&1 | tail -2
$CMAKE --install build 2>/dev/null
echo "[DONE] hyprwayland-scanner -> $PREFIX"

# ── PHASE 2: Build wayland + libinput to /opt/hypr ONLY ──────────────────────
echo ""
echo "[PHASE 2] Building wayland 1.23.1 -> $PREFIX (NOT system)..."
cd ~/wayland
rm -rf build
meson setup build --prefix="$PREFIX" -Ddocumentation=false -Dtests=false 2>&1 | tail -3
ninja -C build -j$JOBS 2>&1 | tail -3
ninja -C build install 2>/dev/null
echo "[DONE] wayland 1.23.1 -> $PREFIX"

echo ""
echo "[PHASE 2] Building libinput 1.28.1 -> $PREFIX (NOT system)..."
cd ~
rm -rf libinput
git clone --depth=1 --branch 1.28.1 https://gitlab.freedesktop.org/libinput/libinput.git
cd libinput
meson setup build --prefix="$PREFIX" -Ddocumentation=false -Dtests=false -Dlibwacom=false 2>&1 | tail -3
ninja -C build -j$JOBS 2>&1 | tail -3
ninja -C build install 2>/dev/null
echo "[DONE] libinput 1.28.1 -> $PREFIX"

# ── PHASE 3: Build xkbcommon to /opt/hypr ────────────────────────────────────
echo ""
echo "[PHASE 3] Building xkbcommon 1.11.0 -> $PREFIX..."
cd ~/libxkbcommon
rm -rf build
meson setup build --prefix="$PREFIX" -Denable-docs=false -Denable-tools=false 2>&1 | tail -3
ninja -C build -j$JOBS 2>&1 | tail -3
ninja -C build install 2>/dev/null
echo "[DONE] xkbcommon 1.11.0 -> $PREFIX"

# ── PHASE 4: aquamarine to /opt/hypr ─────────────────────────────────────────
echo ""
echo "[PHASE 4] Building aquamarine -> $PREFIX..."
cd ~/aquamarine
rm -rf build
$CMAKE --no-warn-unused-cli -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_C_COMPILER=gcc-14 -DCMAKE_CXX_COMPILER=g++-14 -S . -B build 2>&1 | tail -3
$CMAKE --build build -j$JOBS 2>&1 | tail -3
$CMAKE --install build 2>/dev/null
echo "[DONE] aquamarine -> $PREFIX"

# ── PHASE 5: Hyprland 0.54.0 to /opt/hypr ────────────────────────────────────
echo ""
echo "[PHASE 5] Building Hyprland 0.54.0 -> $PREFIX..."
cd ~/Hyprland
rm -rf build
$CMAKE --no-warn-unused-cli \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_C_COMPILER=gcc-14 \
    -DCMAKE_CXX_COMPILER=g++-14 \
    -S . -B build 2>&1 | grep -E 'not found|Error|Configuring done'
if $CMAKE --build build -j$JOBS 2>&1 | tail -5; then
    $CMAKE --install build 2>/dev/null
    echo "[DONE] Hyprland 0.54.0 -> $PREFIX"
else
    echo "[FAIL] Hyprland build failed"
fi

# ── PHASE 6: xdg-desktop-portal-hyprland ─────────────────────────────────────
echo ""
echo "[PHASE 6] Building xdg-desktop-portal-hyprland -> $PREFIX..."
cd ~
rm -rf xdg-desktop-portal-hyprland
git clone --depth=1 --recursive https://github.com/hyprwm/xdg-desktop-portal-hyprland.git
cd xdg-desktop-portal-hyprland
rm -rf build
$CMAKE \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=gcc-14 \
    -DCMAKE_CXX_COMPILER=g++-14 \
    -DCMAKE_INSTALL_LIBEXECDIR="$PREFIX/lib" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -B build 2>&1 | tail -3
$CMAKE --build build -j$JOBS 2>&1 | tail -3
$CMAKE --install build 2>/dev/null
echo "[DONE] xdg-desktop-portal-hyprland -> $PREFIX"

# ── VERIFY ────────────────────────────────────────────────────────────────────
echo ""
echo "[VERIFY]"
for bin in Hyprland hyprctl hyprpm; do
    [ -f "$PREFIX/bin/$bin" ] && echo "  [OK] $bin" || echo "  [MISSING] $bin"
done
for lib in libhyprgraphics libhyprutils libhyprlang libhyprcursor libaquamarine; do
    ls "$PREFIX/lib/"*${lib}* 2>/dev/null | head -1 | grep -q . && echo "  [OK] $lib" || echo "  [MISSING] $lib"
done

echo ""
echo "========================================"
echo " DONE: $(date)"
echo " Run Hyprland with:"
echo "   export PATH=$PREFIX/bin:\$PATH"
echo "   export LD_LIBRARY_PATH=$PREFIX/lib:\$LD_LIBRARY_PATH"
echo "   Hyprland"
echo "========================================"
