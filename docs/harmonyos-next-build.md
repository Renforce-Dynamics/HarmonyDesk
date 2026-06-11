# HarmonyOS NEXT build notes

RustDesk's current mobile client is an Android Flutter application. The Android
APK can only target HarmonyOS releases that still provide Android compatibility.
HarmonyOS NEXT native installation uses Harmony packages such as HAP/APP; an APK
cannot be made native-NEXT-installable by changing Android manifest tags.

This repository adds a best-effort Android-compatible Harmony build path:

```bash
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/28.2.13676358"
export VCPKG_ROOT="$HOME/vcpkg"
export OUTPUT_DIR="/tmp/metabot-outputs-zza/oc_d9830050652d2e785d314fb120e476f8"
flutter/build_harmony_android.sh
```

The script builds an arm64 APK with a temporary manifest overlay from
`flutter/android/app/src/harmonyCompat/AndroidManifest.xml`. The overlay removes
or downgrades Android-only privileged declarations that are likely to be rejected
by HarmonyOS compatibility installers:

- `MANAGE_EXTERNAL_STORAGE`
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
- `SYSTEM_ALERT_WINDOW`
- `RECEIVE_BOOT_COMPLETED`
- boot receiver
- floating window service
- package visibility `queries`
- legacy external storage behavior
- required microphone hardware feature

Expected feature impact:

- File access is limited to app-scoped or picker-backed paths.
- Floating-window controls are disabled.
- Boot autostart is disabled.
- Microphone permission is still requested for audio, but microphone hardware is
  not marked as an installation requirement.
- Screen capture and accessibility service declarations are kept because they are
  core to RustDesk's Android remote-control workflow.

For real HarmonyOS NEXT support, the required path is a native OpenHarmony/
HarmonyOS app module that packages as HAP and replaces Android-specific host
capabilities:

- Flutter shell/embedding for OpenHarmony or ArkUI UI.
- HAP module metadata (`module.json5`) and Harmony permission model.
- Rust FFI built for the OpenHarmony native target, not Android NDK.
- Replacements for Android MediaProjection, AccessibilityService, foreground
  service, boot receiver, overlay window, and storage APIs.
