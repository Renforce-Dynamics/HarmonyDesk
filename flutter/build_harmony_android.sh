#!/usr/bin/env bash

set -euo pipefail

MODE="${MODE:-release}"
HARMONY_PROFILE="${HARMONY_PROFILE:-compat}"
ANDROID_ABI="${ANDROID_ABI:-arm64-v8a}"
FLUTTER_TARGET="${FLUTTER_TARGET:-android-arm64}"
RUST_TARGET="${RUST_TARGET:-aarch64-linux-android}"
NDK_LIB_TARGET="${NDK_LIB_TARGET:-aarch64-linux-android}"
VERSION_NAME="${VERSION_NAME:-1.4.7}"
VERSION_CODE="${VERSION_CODE:-1407000}"
OUTPUT_DIR="${OUTPUT_DIR:-}"
PACKAGE_ID="${PACKAGE_ID:-}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/flutter"
ANDROID_APP_DIR="$FLUTTER_DIR/android/app"
case "$HARMONY_PROFILE" in
  compat)
    OVERLAY="$ANDROID_APP_DIR/src/harmonyCompat/AndroidManifest.xml"
    OUTPUT_FLAVOR="harmonyCompat"
    ;;
  install-safe)
    OVERLAY="$ANDROID_APP_DIR/src/harmonyInstallSafe/AndroidManifest.xml"
    OUTPUT_FLAVOR="harmonyInstallSafe"
    PACKAGE_ID="${PACKAGE_ID:-com.catbaba.harmonydesk}"
    ;;
  client-only)
    OVERLAY="$ANDROID_APP_DIR/src/harmonyClientOnly/AndroidManifest.xml"
    OUTPUT_FLAVOR="harmonyClientOnly"
    PACKAGE_ID="${PACKAGE_ID:-com.catbaba.harmonydesk.client}"
    ;;
  *)
    echo "Unknown HARMONY_PROFILE: $HARMONY_PROFILE" >&2
    exit 1
    ;;
esac
RELEASE_MANIFEST="$ANDROID_APP_DIR/src/release/AndroidManifest.xml"
BUILD_GRADLE="$ANDROID_APP_DIR/build.gradle"

if [[ ! -f "$OVERLAY" ]]; then
  echo "Missing Harmony manifest overlay: $OVERLAY" >&2
  exit 1
fi

if [[ -z "${ANDROID_SDK_ROOT:-}" ]]; then
  export ANDROID_SDK_ROOT="$HOME/android-sdk"
fi

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/28.2.13676358"
fi

export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
export VCPKG_ROOT="${VCPKG_ROOT:-$HOME/vcpkg}"
export PATH="$HOME/flutter/bin:$HOME/.cargo/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

if [[ ! -d "$ANDROID_NDK_HOME" ]]; then
  echo "Missing Android NDK: $ANDROID_NDK_HOME" >&2
  exit 1
fi

if [[ ! -x "$VCPKG_ROOT/vcpkg" ]]; then
  echo "Missing vcpkg executable: $VCPKG_ROOT/vcpkg" >&2
  exit 1
fi

cleanup() {
  if [[ -f "$BUILD_GRADLE.bak-harmony" ]]; then
    mv "$BUILD_GRADLE.bak-harmony" "$BUILD_GRADLE"
  fi
  if [[ -f "$RELEASE_MANIFEST.bak-harmony" ]]; then
    mv "$RELEASE_MANIFEST.bak-harmony" "$RELEASE_MANIFEST"
  else
    rm -f "$RELEASE_MANIFEST"
  fi
}
trap cleanup EXIT

if [[ -f "$RELEASE_MANIFEST" ]]; then
  cp "$RELEASE_MANIFEST" "$RELEASE_MANIFEST.bak-harmony"
fi
mkdir -p "$(dirname "$RELEASE_MANIFEST")"
cp "$OVERLAY" "$RELEASE_MANIFEST"

cp "$BUILD_GRADLE" "$BUILD_GRADLE.bak-harmony"
sed -i 's/signingConfigs.release/signingConfigs.debug/g' "$BUILD_GRADLE"
if [[ -n "$PACKAGE_ID" ]]; then
  sed -i "s/applicationId \"com.carriez.flutter_hbb\"/applicationId \"$PACKAGE_ID\"/g" "$BUILD_GRADLE"
fi

if [[ ! -f "$FLUTTER_DIR/lib/generated_bridge.dart" || ! -f "$ROOT_DIR/src/bridge_generated.rs" ]]; then
  flutter_rust_bridge_codegen \
    --rust-input "$ROOT_DIR/src/flutter_ffi.rs" \
    --dart-output "$FLUTTER_DIR/lib/generated_bridge.dart" \
    --c-output "$ANDROID_APP_DIR/src/main/jniLibs/bridge_generated.h" \
    --llvm-path /usr/lib/llvm-14
fi

cat > "$FLUTTER_DIR/android/local.properties" <<EOF
sdk.dir=$ANDROID_SDK_ROOT
flutter.sdk=$HOME/flutter
flutter.versionName=$VERSION_NAME
flutter.versionCode=$VERSION_CODE
EOF

pushd "$FLUTTER_DIR" >/dev/null
flutter pub get
popd >/dev/null

"$FLUTTER_DIR/build_android_deps.sh" "$ANDROID_ABI"

pushd "$ROOT_DIR" >/dev/null
cargo ndk \
  --platform 21 \
  --target "$RUST_TARGET" \
  --bindgen \
  build \
  --locked \
  --release \
  --features flutter,hwcodec
popd >/dev/null

JNI_DIR="$ANDROID_APP_DIR/src/main/jniLibs/$ANDROID_ABI"
mkdir -p "$JNI_DIR"
cp "$ROOT_DIR/target/$RUST_TARGET/release/liblibrustdesk.so" "$JNI_DIR/librustdesk.so"
cp "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/$NDK_LIB_TARGET/libc++_shared.so" "$JNI_DIR/"
"$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" "$JNI_DIR"/*

pushd "$FLUTTER_DIR" >/dev/null
flutter build apk "--$MODE" --target-platform "$FLUTTER_TARGET" --split-per-abi
popd >/dev/null

APK="$FLUTTER_DIR/build/app/outputs/flutter-apk/app-$ANDROID_ABI-$MODE.apk"
FINAL_APK="$ROOT_DIR/rustdesk-$VERSION_NAME-$OUTPUT_FLAVOR-$ANDROID_ABI.apk"
cp "$APK" "$FINAL_APK"

if [[ -n "$OUTPUT_DIR" ]]; then
  mkdir -p "$OUTPUT_DIR"
  cp "$FINAL_APK" "$OUTPUT_DIR/"
fi

echo "$FINAL_APK"
