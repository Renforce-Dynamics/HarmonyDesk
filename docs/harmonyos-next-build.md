# HarmonyDesk HarmonyOS Build Notes

HarmonyDesk is built from RustDesk's Android Flutter client. The artifacts in
this repository are Android APKs for HarmonyOS releases that still provide
Android compatibility mode.

HarmonyOS NEXT native installation uses Harmony packages such as HAP/APP. An
APK cannot become a native HarmonyOS NEXT package by changing Android manifest
tags. Native NEXT support requires a separate OpenHarmony/HarmonyOS application
module.

## Recommended Artifact

Use the client-only profile when the phone is only used to control remote
devices:

```bash
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/28.2.13676358"
export VCPKG_ROOT="$HOME/vcpkg"

HARMONY_PROFILE=client-only flutter/build_harmony_android.sh
```

Output:

```text
rustdesk-1.4.7-harmonyClientOnly-arm64-v8a.apk
```

Default package ID:

```text
com.catbaba.harmonydesk.client
```

Application label:

```text
HarmonyDesk
```

## Profiles

The build script applies a temporary Android manifest overlay from
`flutter/android/app/src/<profile>/AndroidManifest.xml`.

| `HARMONY_PROFILE` | Overlay | Output flavor | Default package ID |
| --- | --- | --- | --- |
| `client-only` | `harmonyClientOnly` | `harmonyClientOnly` | `com.catbaba.harmonydesk.client` |
| `install-safe` | `harmonyInstallSafe` | `harmonyInstallSafe` | `com.catbaba.harmonydesk` |
| `compat` | `harmonyCompat` | `harmonyCompat` | `com.carriez.flutter_hbb` |

### client-only

Recommended for this fork. The phone is a controller/client only.

Keeps:

- `android.permission.INTERNET`
- `android.permission.ACCESS_NETWORK_STATE`
- generated dynamic receiver permission

Removes:

- `MainService`
- `InputService`
- `FloatingWindowService`
- `PermissionRequestTransparentActivity`
- AccessibilityService declarations
- MediaProjection / foreground service declarations
- wake lock
- boot receiver
- floating window
- storage permissions
- notification permission
- camera and microphone permissions/features
- RustDesk deep-link scheme

Expected impact:

- The phone can be used as a remote-control client.
- The phone cannot be controlled as a host.
- The phone cannot share its screen through the removed host service.
- Android accessibility input, microphone recording, QR scanning, host
  notifications, and host foreground service behavior are unavailable.

### install-safe

This is a transitional installer-compatibility profile. It removes most
sensitive declarations but still declares the main host service class.

Use it only for diagnosis when comparing installer behavior.

### compat

This profile is closest to upstream Android RustDesk. It keeps host-side
remote-control declarations such as AccessibilityService and MediaProjection.

It removes or downgrades some Android-only privileged declarations:

- `MANAGE_EXTERNAL_STORAGE`
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
- `SYSTEM_ALERT_WINDOW`
- `RECEIVE_BOOT_COMPLETED`
- boot receiver
- floating window service
- package visibility `queries`
- legacy external storage behavior
- required microphone hardware feature

This profile may still be blocked by strict HarmonyOS/Huawei package scanning.

## Build Script

The script is:

```text
flutter/build_harmony_android.sh
```

Useful environment variables:

```bash
MODE=release
HARMONY_PROFILE=client-only
ANDROID_ABI=arm64-v8a
FLUTTER_TARGET=android-arm64
RUST_TARGET=aarch64-linux-android
ANDROID_SDK_ROOT=$HOME/android-sdk
ANDROID_NDK_HOME=$ANDROID_SDK_ROOT/ndk/28.2.13676358
VCPKG_ROOT=$HOME/vcpkg
OUTPUT_DIR=/path/to/output
PACKAGE_ID=com.example.custom.package
```

`PACKAGE_ID` can override the default package ID for the selected profile.

## Validation

Check the package label, package ID, permissions, and signature:

```bash
APK=rustdesk-1.4.7-harmonyClientOnly-arm64-v8a.apk

$ANDROID_SDK_ROOT/build-tools/34.0.0/aapt dump badging "$APK"
$ANDROID_SDK_ROOT/build-tools/34.0.0/aapt dump permissions "$APK"
$ANDROID_SDK_ROOT/build-tools/34.0.0/aapt dump xmltree "$APK" AndroidManifest.xml
$ANDROID_SDK_ROOT/build-tools/34.0.0/apksigner verify --verbose --print-certs "$APK"
```

For `client-only`, the manifest should not contain:

- `MainService`
- `InputService`
- `FloatingWindowService`
- `PermissionRequestTransparentActivity`
- `BIND_ACCESSIBILITY_SERVICE`
- `AccessibilityService`
- `foregroundServiceType`
- `FOREGROUND_SERVICE`
- `WAKE_LOCK`
- `RECORD_AUDIO`
- `CAMERA`
- `POST_NOTIFICATIONS`
- `MANAGE_EXTERNAL_STORAGE`
- `SYSTEM_ALERT_WINDOW`
- `RECEIVE_BOOT_COMPLETED`
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

## Troubleshooting

If Gradle fails with a stale merged resource error such as
`abc_btn_colored_material.xml`, clean Flutter build outputs and rebuild:

```bash
cd flutter
/vepfs/users/zza/flutter/bin/flutter clean
cd ..
HARMONY_PROFILE=client-only flutter/build_harmony_android.sh
```

Gradle may print Kotlin metadata incompatibility lines prefixed with `e:` while
still completing successfully in this build environment.

## Native HarmonyOS NEXT Path

A real HarmonyOS NEXT application requires a native Harmony package, not an
Android APK. That path would need:

- HAP module metadata such as `module.json5`
- Harmony permission declarations
- ArkUI or a Flutter/OpenHarmony embedding
- Rust FFI built for an OpenHarmony native target instead of Android NDK
- replacements for Android MediaProjection, AccessibilityService, foreground
  service, boot receiver, overlay window, and storage APIs
