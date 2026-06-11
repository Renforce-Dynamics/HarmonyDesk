# HarmonyDesk

HarmonyDesk is a HarmonyOS-oriented Android compatibility build of RustDesk,
focused on using a phone as a remote-control client. It is based on the
upstream RustDesk Flutter/Android application, with branding, Android manifest
profiles, and build automation adjusted for stricter HarmonyOS/Huawei package
installers.

The recommended build profile is `client-only`: the phone can control remote
devices, but the phone is not exposed as a remotely controlled host.

## Status

- Base project: RustDesk, commit `84af60c`
- Target artifact: arm64 Android APK for HarmonyOS Android compatibility mode
- Recommended profile: `HARMONY_PROFILE=client-only`
- App label: `HarmonyDesk`
- Default client-only package ID: `com.catbaba.harmonydesk.client`
- Native HarmonyOS NEXT HAP: not supported by this branch

## Why Client-Only

Some HarmonyOS/Huawei installers block APKs that look like mobile remote-control
hosts. The client-only profile removes host-side capabilities that are not
needed when the phone is only used to control another computer or device.

The client-only APK keeps only:

- `android.permission.INTERNET`
- `android.permission.ACCESS_NETWORK_STATE`
- the app's generated dynamic receiver permission

It removes Android declarations for:

- AccessibilityService / remote input service
- screen capture / MediaProjection host service
- foreground host service and wake lock
- floating window service
- boot autostart receiver
- camera, microphone, notification, and storage permissions
- RustDesk deep-link scheme

## Build

Prepare the toolchain first. The known-good local build used:

- Rust 1.75.0 with `aarch64-linux-android`
- Flutter 3.24.5
- Android SDK build-tools 34.0.0
- Android NDK 28.2.13676358
- `cargo-ndk`, `flutter_rust_bridge_codegen`, and vcpkg dependencies

Build the recommended client-only APK:

```bash
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/28.2.13676358"
export VCPKG_ROOT="$HOME/vcpkg"

HARMONY_PROFILE=client-only flutter/build_harmony_android.sh
```

The output is written to:

```text
rustdesk-1.4.7-harmonyClientOnly-arm64-v8a.apk
```

To copy the APK to an external output directory:

```bash
export OUTPUT_DIR=/path/to/output
HARMONY_PROFILE=client-only flutter/build_harmony_android.sh
```

## Build Profiles

`flutter/build_harmony_android.sh` supports three Harmony profiles:

| Profile | Output flavor | Purpose |
| --- | --- | --- |
| `client-only` | `harmonyClientOnly` | Recommended. Phone controls remote devices only. Removes host-side services and sensitive permissions. |
| `install-safe` | `harmonyInstallSafe` | Transitional installability test. Removes most sensitive declarations but still leaves the main host service class declared. |
| `compat` | `harmonyCompat` | Closest to upstream Android RustDesk. Keeps AccessibilityService and MediaProjection declarations and may be blocked by strict installers. |

See [docs/harmonyos-next-build.md](docs/harmonyos-next-build.md) for the
complete profile details.

## Validation

Useful checks after building:

```bash
APK=rustdesk-1.4.7-harmonyClientOnly-arm64-v8a.apk

$ANDROID_SDK_ROOT/build-tools/34.0.0/aapt dump badging "$APK"
$ANDROID_SDK_ROOT/build-tools/34.0.0/aapt dump permissions "$APK"
$ANDROID_SDK_ROOT/build-tools/34.0.0/apksigner verify --verbose --print-certs "$APK"
```

For the client-only build, `aapt` should not show declarations such as
`AccessibilityService`, `MainService`, `FOREGROUND_SERVICE`, `WAKE_LOCK`,
`RECORD_AUDIO`, `CAMERA`, `POST_NOTIFICATIONS`, `SYSTEM_ALERT_WINDOW`, or
`RECEIVE_BOOT_COMPLETED`.

## Limitations

This branch still builds an Android APK. It is not a native HarmonyOS NEXT
application and it does not produce a HAP package.

The client-only profile intentionally disables or removes mobile host features:

- this phone cannot be controlled remotely
- this phone cannot share its screen as a host
- Android accessibility-based input is unavailable
- camera scanning and microphone recording are unavailable
- host notifications and foreground host service behavior are unavailable

For native HarmonyOS NEXT support, a separate OpenHarmony/HarmonyOS app module
is required, including HAP packaging, Harmony permissions, and replacements for
Android-specific APIs.

## Upstream

HarmonyDesk is derived from RustDesk. RustDesk is a remote desktop solution
written in Rust with Flutter and native platform integrations.

Upstream project: <https://github.com/rustdesk/rustdesk>

Please respect RustDesk's license and security expectations. Do not use this
software for unauthorized access or activity that violates privacy, policy, or
law.
