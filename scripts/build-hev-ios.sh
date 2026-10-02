#!/usr/bin/env bash
set -euo pipefail

# Build only the libraries consumed by the iOS app. The upstream Apple script
# also compiles macOS and tvOS libraries, which are unnecessary for an IPA.
HEV_SOURCE=${1:?Usage: build-hev-ios.sh ENGINE_DIR OUTPUT_DIR [true|false]}
HEV_OUTPUT=${2:?Usage: build-hev-ios.sh ENGINE_DIR OUTPUT_DIR [true|false]}
HEV_INCLUDE_SIMULATORS=${3:-false}

case "$HEV_INCLUDE_SIMULATORS" in
    true|false) ;;
    *) echo 'The simulator option must be true or false.' >&2; exit 1 ;;
esac
for tool in make xcrun xcodebuild; do
    command -v "$tool" >/dev/null || { echo "Missing Apple build tool: $tool" >&2; exit 1; }
done
HEV_JOBS=${BUILD_JOBS:-$(sysctl -n hw.logicalcpu)}
case "$HEV_JOBS" in
    ''|*[!0-9]*|0) echo 'BUILD_JOBS must be a positive integer.' >&2; exit 1 ;;
esac
HEV_SOURCE=$(cd "$HEV_SOURCE" && pwd)
test -f "$HEV_SOURCE/src/hev-main.h"
test -f "$HEV_SOURCE/module.modulemap"
if [ -e "$HEV_OUTPUT" ]; then
    echo "Output already exists; preserve it or choose another output path: $HEV_OUTPUT" >&2
    exit 1
fi
mkdir -p "$(dirname "$HEV_OUTPUT")"
HEV_OUTPUT="$(cd "$(dirname "$HEV_OUTPUT")" && pwd)/$(basename "$HEV_OUTPUT")"
HEV_TEMP=$(mktemp -d "${TMPDIR:-/tmp}/hev-socks5-ios.XXXXXX")
trap 'rm -rf -- "$HEV_TEMP"' EXIT

build_static() {
    local sdk=$1
    local arch=$2
    local output="$HEV_TEMP/$sdk-$arch/libhev-socks5-server.a"
    echo "Building $sdk $arch with $HEV_JOBS jobs"
    # Different SDKs and architectures must never share compiled object files.
    make -C "$HEV_SOURCE" clean
    make -C "$HEV_SOURCE" -j"$HEV_JOBS" \
        PP="xcrun --sdk $sdk clang" \
        CC="xcrun --sdk $sdk clang" \
        CFLAGS="-arch $arch -m$sdk-version-min=15.0" \
        LFLAGS="-arch $arch -m$sdk-version-min=15.0 -Wl,-Bsymbolic-functions" \
        static
    mkdir -p "$(dirname "$output")"
    xcrun --sdk "$sdk" libtool -static -o "$output" \
        "$HEV_SOURCE/bin/libhev-socks5-server.a" \
        "$HEV_SOURCE/third-part/yaml/bin/libyaml.a" \
        "$HEV_SOURCE/third-part/hev-task-system/bin/libhev-task-system.a"
}

build_static iphoneos arm64
mkdir -p "$HEV_TEMP/include"
cp "$HEV_SOURCE/src/hev-main.h" "$HEV_TEMP/include/"
cp "$HEV_SOURCE/module.modulemap" "$HEV_TEMP/include/"
HEV_FRAMEWORK_ARGS=(
    -library "$HEV_TEMP/iphoneos-arm64/libhev-socks5-server.a"
    -headers "$HEV_TEMP/include"
)

if [ "$HEV_INCLUDE_SIMULATORS" = true ]; then
    build_static iphonesimulator arm64
    build_static iphonesimulator x86_64
    mkdir -p "$HEV_TEMP/iphonesimulator-universal"
    xcrun lipo -create \
        "$HEV_TEMP/iphonesimulator-arm64/libhev-socks5-server.a" \
        "$HEV_TEMP/iphonesimulator-x86_64/libhev-socks5-server.a" \
        -output "$HEV_TEMP/iphonesimulator-universal/libhev-socks5-server.a"
    HEV_FRAMEWORK_ARGS+=(
        -library "$HEV_TEMP/iphonesimulator-universal/libhev-socks5-server.a"
        -headers "$HEV_TEMP/include"
    )
fi

make -C "$HEV_SOURCE" clean
xcodebuild -create-xcframework "${HEV_FRAMEWORK_ARGS[@]}" -output "$HEV_OUTPUT"
