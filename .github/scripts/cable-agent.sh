#!/usr/bin/env bash
set -euo pipefail

# CI Cable Agent - orchestrates full build, failure detection, and auto-fix loop.
# Designed for GitHub Actions or local use.

LOG_DIR="$(pwd)/.github/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/cable-agent-$(date -u +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================"
echo "CI Cable Agent start: $(date -u)"
echo "Log: $LOG_FILE"
echo "========================================"

# Retry loop up to 3 times if known errors are detected.
MAX_RETRIES=3
retry=0

while (( retry < MAX_RETRIES )); do
    retry=$((retry + 1))
    echo "\n[STEP] Run build_all.sh (attempt $retry/$MAX_RETRIES)"

    if [[ -x "$(pwd)/build_all.sh" ]]; then
        # This script may require sudo privileges; runners usually allow passwordless sudo on GitHub hosted images.
        if bash ./build_all.sh ""; then
            echo "✅ Build sequence completed successfully."
            exit 0
        fi
    else
        echo "⚠️ build_all.sh not found or not executable; aborting."
        exit 1
    fi

    # Collect top failure tail from log for matching.
    echo "⚠️ Build failed in attempt $retry, analyzing failure patterns..."
    FAIL_BODY=$(tail -n 200 "$LOG_FILE" | sed -n '/error\|failed\|undefined reference/p')
    echo "$FAIL_BODY"

    if echo "$FAIL_BODY" | grep -qi "libinput_device_get_id_bustype"; then
        echo "🔧 Applying libinput symbol fixer (CMAKE link flags)."
        # Ensure workflow has known patch settings in the build config
        # also apply inline for flexible path
        sed -i 's|-DCMAKE_PREFIX_PATH=.*|-DCMAKE_PREFIX_PATH="/opt/hypr:/usr/local" -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/local/lib -L/opt/hypr/lib -Wl,-rpath,/usr/local/lib,/opt/hypr/lib" -DCMAKE_EXE_LINKER_FLAGS="-L/usr/local/lib -L/opt/hypr/lib -Wl,-rpath,/usr/local/lib,/opt/hypr/lib"|' .github/workflows/build.yml || true
        continue
    fi

    if echo "$FAIL_BODY" | grep -qi "CMake.*can't find package\|Could not find.*package"; then
        echo "🔧 Applying CMAKE_PREFIX_PATH auto-fix."
        sed -i 's|-DCMAKE_PREFIX_PATH=.*|-DCMAKE_PREFIX_PATH="/opt/hypr:/usr/local:/usr"|' .github/workflows/build.yml || true
        continue
    fi

    if echo "$FAIL_BODY" | grep -qi "undefined reference"; then
        echo "🔧 Adding relaxed linker flags for missing symbols."
        sed -i 's|\(CMAKE_SHARED_LINKER_FLAGS=.*\)|\1 -Wl,--as-needed|' .github/workflows/build.yml || true
        continue
    fi

    echo "⚠️ Unrecognized failure pattern; aborting after $retry attempts."
    break

done

# Final state after retries
if (( retry >= MAX_RETRIES )); then
    echo "⚠️ Build failed after $MAX_RETRIES attempts. Please inspect the log at $LOG_FILE."
    exit 1
fi

exit 0
