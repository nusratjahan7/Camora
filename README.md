# Camera Overlay

A Flutter app that lets you line up a shot by floating a reference image from your
gallery over the device's live camera preview, tuning its opacity, and capturing the
composite. Built for Android and iOS.

> **Module status — foundation only.** This build ships the project skeleton:
> architecture, theming, routing, error handling, permissions and every native
> dependency (camera, image picker, gallery saving, local storage, file handling).
> The camera preview is live. Overlay alignment, opacity control and capture are the
> next module and are intentionally not implemented yet.

---

## Requirements

| Tool | Version used |
| --- | --- |
| Flutter | 3.44.6 (stable) |
| Dart | 3.12.2 |
| Android SDK | platform **android-37**, build-tools 37.0.0, `minSdk 24` |
| Xcode (iOS) | 15+ on macOS, deployment target 12.0 |

Dependencies (latest mutually compatible stable releases, resolved by `flutter pub`):

| Package | Version | Purpose |
| --- | --- | --- |
| `flutter_riverpod` | 3.4.3 | state management |
| `go_router` | 18.0.2 | declarative routing |
| `camera` | 0.12.1 | live camera preview |
| `image_picker` | 1.2.4 | picking a reference image |
| `gal` | 2.3.3 | saving captures to the photo gallery |
| `permission_handler` | 13.0.2 | runtime permission requests |
| `shared_preferences` | 2.5.6 | local settings storage |
| `path_provider` | 2.1.6 | app directory / file handling |
| `path` | 1.9.1 | cross-platform path joins |

---

## Project structure

Feature-first layout: cross-cutting concerns in `core`, feature slices in `features`,
and re-usable UI in `shared`.

```
lib/
├── main.dart                       # entry point -> bootstrap()
├── app/
│   ├── bootstrap.dart              # error zones, runApp, ProviderScope
│   ├── app.dart                    # MaterialApp.router
│   └── router/
│       ├── app_routes.dart         # route paths + names
│       └── app_router.dart         # GoRouter provider, error handling
├── core/                           # framework-agnostic building blocks
│   ├── constants/                  # app + storage keys
│   ├── errors/                     # AppException hierarchy + AppErrorHandler
│   ├── logging/                    # AppLogger
│   ├── permissions/                # AppPermission, PermissionService
│   ├── storage/                    # KeyValueStore + SharedPreferences impl
│   ├── files/                      # FileService (capture directory/files)
│   └── theme/                      # colors, spacing, typography, CameraTheme, AppTheme
├── shared/
│   ├── widgets/                    # AppButton, AppIconButton, AppSlider, views, sheets
│   └── extensions/                 # BuildContext helpers (colors, text, snackbars)
└── features/
    ├── home/       presentation/pages/
    ├── camera/     presentation/{pages,providers,widgets}/
    ├── overlay/    domain/, presentation/providers/
    ├── gallery/    data/           # ImagePickerService, GallerySaverService
    └── settings/   domain/, data/, presentation/{providers,pages}/
```

Each feature follows `domain` (models) → `data` (services/repositories) →
`presentation` (providers, pages, widgets). Providers are co-located with the service
or repository they expose.

---

## Installation

```bash
git clone <your-repo-url> camora
cd camora
flutter pub get
```

Verify your toolchain:

```bash
flutter doctor -v
```

---

## Running on Android

1. **Install the required SDK components.** `permission_handler` 13 compiles against
   `compileSdk 37`, and Flutter pins NDK `28.2.13676358`, so the app is configured with
   `compileSdk = 37`. Install both:

   ```bash
   sdkmanager "platforms;android-37" "ndk;28.2.13676358"
   flutter doctor --android-licenses   # accept any pending licenses
   ```

   The Android SDK directory must be writable by your user (`sdk.dir` in
   `android/local.properties`); otherwise Gradle cannot auto-install missing components
   and the build fails with `The SDK directory is not writable`.

2. Start a device or emulator, then run:

   ```bash
   flutter devices
   flutter run -d <device-id>          # or simply: flutter run
   ```

3. Build an APK:

   ```bash
   flutter build apk --debug           # debug
   flutter build apk --release         # release (add your signing config first)
   ```

---

## Building on iOS

Building requires macOS with Xcode installed. Flutter 3.44 uses **Swift Package
Manager** by default, so no `Podfile` is generated or required.

```bash
cd ios
# Only needed if a plugin without SPM support is ever added:
# pod install
cd ..

flutter run -d <ios-device-id>
flutter build ios --release              # archive-ready build
```

To ship: open `ios/Runner.xcworkspace` in Xcode, set your signing team, then
**Product → Archive**.

---

## Permissions

Permissions are requested **only at the moment they are needed**, and a rationale
sheet explains the reason before the system prompt appears.

| Permission | When it is requested | Why |
| --- | --- | --- |
| Camera | On opening the shooting screen | Show the live preview that the reference image is aligned against. Used only while that screen is open. |
| Photo library (read) | When choosing a reference image | Select the image to overlay. |
| Photo library (add) | When saving a capture | Write the finished photo back to the gallery. |

Nothing leaves the device — there is no backend, account or analytics.

### Android — `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="29" />
<!-- Audio is never recorded, so the camera plugin's RECORD_AUDIO is stripped. -->
<uses-permission android:name="android.permission.RECORD_AUDIO" tools:node="remove" />
<uses-feature android:name="android.hardware.camera.any" android:required="true" />
```

`WRITE_EXTERNAL_STORAGE` is capped at API 29, the last version that needs it to save
into the gallery. API 30+ uses scoped storage, and the Android 13+ photo picker needs
no storage permission at all.

### iOS — `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>…</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>…</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>…</string>
```

With SPM, `permission_handler_apple` (9.6.2) **derives its `PERMISSION_*` macros from
these `Info.plist` keys automatically** — the only permissions declared here are the
ones compiled into the app. No Podfile macros are needed. If you edit the plist, clear
DerivedData once so the package manifest is re-evaluated:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

---

## Architecture notes

- **State management** — Riverpod 3. Camera lifecycle uses an `AsyncNotifier` with
  `autoDispose`, so the camera is released when the preview is disposed. Settings use a
  keep-alive `AsyncNotifier` with optimistic updates.
- **Routing** — a single `GoRouter` provided by `appRouterProvider`, with a shared
  `errorBuilder` for unknown routes.
- **Error handling** — every failure is normalised to a sealed `AppException`
  (`CameraFailure`, `PermissionFailure`, `GallerySaveFailure`, …) by `AppErrorHandler`,
  which also logs and offers a `guard()` helper. Framework, platform and zone errors are
  captured in `bootstrap.dart`.
- **Theme** — a reusable dark-first system in `core/theme` (`AppColors`, `AppSpacing`,
  `AppTypography`, `AppTheme`) plus a `CameraTheme` `ThemeExtension` for camera-specific
  tokens (scrim, shutter, guides). Controls meet the 48 dp minimum tap target and expose
  semantics labels.

---

## Testing

```bash
flutter analyze     # static analysis — expects zero issues
flutter test        # unit + widget tests
```

---

## Not implemented yet (next module)

- Choosing a reference image and rendering it over the preview (`ImagePickerService` and
  `GallerySaverService` are wired and ready).
- Opacity, scale, rotation and drag alignment of the overlay (`OverlaySettings` state is
  in place).
- Compositing the overlay with the camera frame and saving to the gallery.
