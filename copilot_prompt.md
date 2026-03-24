# Fix build.yml - Aquamarine CMake Error + General Build Error Handling

## Context
File: `build.yml` (GitHub Actions workflow)
Building: Hyprland 0.54.0 + dependencies on ubuntu-24.04
All libs install to: `/opt/hypr`

## Current Error
```
CMakeLists.txt:156 uses target_link_libraries with the "plain signature"
for target "aquamarine" multiple times.
Policy CMP0023: mixing plain and keyword signatures is not allowed.
```

## Root Cause
In the "Build aquamarine" step, we append these lines to CMakeLists.txt:
```cmake
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBINPUT REQUIRED libinput)
target_link_libraries(aquamarine PRIVATE ${LIBINPUT_LIBRARIES})
target_include_directories(aquamarine PRIVATE ${LIBINPUT_INCLUDE_DIRS})
```
But aquamarine's existing CMakeLists.txt already has `target_link_libraries(aquamarine ...)` using the plain signature (no PUBLIC/PRIVATE keyword). Mixing both causes the CMake error.

## Fix Required (in build.yml aquamarine step)
Replace the append approach with cmake linker flags instead:
- Remove the 4 `echo '...' >> CMakeLists.txt` lines
- Pass libinput linking via cmake flags:
  `-DCMAKE_SHARED_LINKER_FLAGS="-L/opt/hypr/lib -linput"`
  `-DCMAKE_EXE_LINKER_FLAGS="-L/opt/hypr/lib -linput"`

The aquamarine cmake step should look like:
```yaml
- name: Build aquamarine
  run: |
    set -e
    pkg-config --modversion libinput
    echo "libinput libs: $(pkg-config --libs libinput)"
    git clone --depth=1 https://github.com/hyprwm/aquamarine.git
    cd aquamarine
    cmake --no-warn-unused-cli \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=$PREFIX \
      -DCMAKE_C_COMPILER=gcc-14 \
      -DCMAKE_CXX_COMPILER=g++-14 \
      -DCMAKE_PREFIX_PATH=$PREFIX \
      -DAQUAMARINE_BUILD_TESTS=OFF \
      -DCMAKE_SHARED_LINKER_FLAGS="-L/opt/hypr/lib -linput" \
      -DCMAKE_EXE_LINKER_FLAGS="-L/opt/hypr/lib -linput" \
      -S . -B build
    cmake --build build -j$(nproc)
    cmake --install build
```

## General Rules for ALL Future Build Errors in this workflow

1. **Undefined reference to symbol**: Add `-L/opt/hypr/lib -l<libname>` to CMAKE_SHARED_LINKER_FLAGS for that component's cmake step. Never patch CMakeLists.txt by appending target_link_libraries.

2. **CMake can't find package**: Add `-DCMAKE_PREFIX_PATH=/opt/hypr` to that component's cmake configure command.

3. **Binary not found (e.g. hyprwayland-scanner not found)**: Add `echo "/opt/hypr/bin" >> $GITHUB_PATH` as a separate step before the failing step.

4. **Test binary link failure**: Add `-D<PROJECT>_BUILD_TESTS=OFF` to cmake configure. Never let test failures block the main library install.

5. **append_range compile error**: Replace `.append_range(x)` with `.insert(end(), x.begin(), x.end())` using sed on the source files before building.

6. **native_handle() compile error**: Remove the offending line with sed before building.

7. **Mixing cmake plain/keyword signature**: Never append target_link_libraries to CMakeLists.txt. Use CMAKE_SHARED_LINKER_FLAGS or CMAKE_EXE_LINKER_FLAGS instead.

8. **pkg-config not finding /opt/hypr libs**: PKG_CONFIG_PATH must include `/opt/hypr/lib/pkgconfig:/opt/hypr/lib/x86_64-linux-gnu/pkgconfig:/opt/hypr/share/pkgconfig` — already set in "Set env" step, verify it's inherited.

## Apply the fix to build.yml now.

---

# Full Project State & Goal

## Goal
Successfully build Hyprland 0.54.0 + all dependencies from source on GitHub Actions (ubuntu-24.04), package as `hyprland-0.54.0-ubuntu24-x86_64.tar.gz`, upload as artifact, then deploy to M2 (Ubuntu 24.04, IP 192.168.1.8, user `zulqarnain`).

## Current State
- GitHub repo: `zulqarnain1066-hub/hyprland-build` (private)
- Workflow file: `.github/workflows/build.yml`
- All builds install to `/opt/hypr` (NOT system paths)
- Build order: hyprutils → hyprlang → hyprcursor → hyprgraphics → hyprwayland-scanner → wayland 1.23.1 → libinput 1.28.1 → xkbcommon 1.11.0 → aquamarine → hyprwire → xcb-errors → hyprland-protocols → Hyprland 0.54.0 → xdg-desktop-portal-hyprland
- Steps 1–13 all pass successfully
- Currently failing at step 14: **Build aquamarine** (fix being applied now)
- Steps 15–21 (hyprwire, xcb-errors, hyprland-protocols, Hyprland, xdg-portal, package, upload) are all untested — they may have their own errors

## Known Patches Already Applied
- hyprutils: `sed -i 's/fcntl(m_impl->m_logOfs.native_handle()...)//' src/cli/Logger.cpp`
- hyprwire: `find src -name '*.cpp' -o -name '*.hpp' | xargs sed -i 's/\.append_range(\(.*\));/.insert(m_data.end(), \1.begin(), \1.end());/g'`
- hyprwire: `-DCMAKE_CXX_STANDARD=23`
- aquamarine: `-DAQUAMARINE_BUILD_TESTS=OFF`
- aquamarine: `-DCMAKE_SHARED_LINKER_FLAGS="-L/opt/hypr/lib -linput"` (current fix)

## Environment Variables (set in "Set env" step)
```
CC=gcc-14
CXX=g++-14
PREFIX=/opt/hypr
PKG_CONFIG_PATH=/opt/hypr/lib/pkgconfig:/opt/hypr/lib/x86_64-linux-gnu/pkgconfig:/opt/hypr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig
CMAKE_PREFIX_PATH=/opt/hypr
LD_LIBRARY_PATH=/opt/hypr/lib:/opt/hypr/lib/x86_64-linux-gnu
PATH includes /opt/hypr/bin
```

## Your Job (Copilot)
After applying the aquamarine fix above, your ongoing responsibility is:

1. **Monitor each build step in order.** When a step fails, read the error, apply the correct fix from the rules above, update `build.yml`, and continue.

2. **For each remaining step that hasn't been tested yet** (hyprwire, xcb-errors, hyprland-protocols, Hyprland 0.54.0, xdg-desktop-portal-hyprland), anticipate and pre-apply known fixes:
   - All cmake steps must have `-DCMAKE_PREFIX_PATH=/opt/hypr`
   - All cmake steps must have `-DCMAKE_C_COMPILER=gcc-14 -DCMAKE_CXX_COMPILER=g++-14`
   - Hyprland 0.54.0 cmake must have `-DCMAKE_PREFIX_PATH=/opt/hypr`
   - xdg-desktop-portal-hyprland cmake must have `-DCMAKE_PREFIX_PATH=/opt/hypr`

3. **Never break passing steps.** Only modify the failing step and steps after it.

4. **When all 21 steps pass**, the artifact `hyprland-0.54.0-ubuntu24-x86_64.tar.gz` will be uploaded. That is the success condition.

5. **After successful artifact upload**, provide the deployment commands to run on M2:
   ```bash
   # On M2 (192.168.1.8)
   cd ~
   tar -xzf hyprland-0.54.0-ubuntu24-x86_64.tar.gz
   echo 'export PATH=/opt/hypr/bin:$PATH' >> ~/.bashrc
   echo 'export LD_LIBRARY_PATH=/opt/hypr/lib:/opt/hypr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH' >> ~/.bashrc
   sudo ldconfig /opt/hypr/lib /opt/hypr/lib/x86_64-linux-gnu
   ```

6. **Token for GitHub API** (if needed to trigger runs or check status):
   `TOKEN_REMOVED`
   Repo: `zulqarnain1066-hub/hyprland-build`

## Success Condition
All 21 steps green + artifact uploaded = DONE.
