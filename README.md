<p align="center"><img src="assets/branding/veylora_icon_256.png" width="128" alt="Veylora logo"></p>

# Veylora

*Create what you envision.*

A Flutter app that lets you line up a shot by floating a reference image from your
gallery over the device's live camera preview, tuning its opacity, and capturing the
shot. The reference is only a guide and is never saved into your photos. Built for
Android and iOS.

> **Capture and saving are live.** The camera preview, the reference overlay and
> its opacity/position controls, and photo capture all work. The shutter saves the
> camera's own image straight to the photo library — the preview, the controls and
> the reference overlay are never part of it — and returns to the camera.

---

## Requirements

| Tool | Version used |
| --- | --- |
| Flutter | 3.44.6 (stable) |
| Dart | 3.12.2 |
| Android SDK | platform **android-37.0**, NDK 28.2.13676358, CMake 3.22.1, build-tools 37.0.0, `minSdk 24` |
| Xcode (iOS) | 15+ on macOS, deployment target 13.0 (required by `camera_avfoundation`) |

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
   sdkmanager "platforms;android-37.0" "ndk;28.2.13676358" "cmake;3.22.1"
   flutter doctor --android-licenses   # accept any pending licenses
   ```

   The Android SDK directory must be writable by your user (`sdk.dir` in
   `android/local.properties`); otherwise Gradle cannot auto-install missing components
   and the build fails with `The SDK directory is not writable`. If the SDK lives in a
   shared, admin-only folder, run `sdkmanager` from an elevated prompt.

   If Kotlin fails with `Could not close incremental caches` (the project and the pub
   cache are on different drives on Windows), add `kotlin.incremental=false` to your
   user-level `~/.gradle/gradle.properties`.

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

### Testing the camera on an iPhone

The iOS Simulator has no camera, so the camera module must be tested on a device.

1. Connect the iPhone, trust the Mac, and enable **Developer Mode**
   (Settings → Privacy & Security).
2. In Xcode, select the **Runner** target → *Signing & Capabilities* → choose your team.
3. `flutter run -d <iphone-id>`, open the camera, and check:
   - the rationale sheet appears before the system camera prompt;
   - denying, then reopening the screen shows **Camera access is blocked** with
     *Open settings* (iOS never re-prompts after a denial); enabling access in Settings
     and returning shows the preview without restarting;
   - rear camera by default; switching to the front camera hides the flash button;
   - flash cycles off → auto → on → torch on the rear camera; pinch and the slider zoom;
     tapping the preview shows the focus reticle;
   - rapid shutter taps capture one photo at a time;
   - Control Center / app switcher releases the camera (green indicator goes off) and
     returning reopens it.

---

## Permissions

Permissions are requested **only at the moment they are needed**, and a rationale
sheet explains the reason before the system prompt appears.

| Permission | When it is requested | Why |
| --- | --- | --- |
| Camera | On opening the shooting screen | Show the live preview that the reference image is aligned against. Used only while that screen is open. |
| Photo library (read) | Never prompted | Reference images come from the system Photo Picker (Android) / PHPicker (iOS), which need no permission. |
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

- **State management** — Riverpod 3. `CameraSessionController` (an auto-dispose
  `AsyncNotifier`) owns the `CameraController`: it opens the rear camera by default,
  releases it when the app leaves the foreground and reopens the same lens on return,
  guards against overlapping captures, and coalesces zoom calls. Widgets never touch the
  plugin; `CameraService` is the only seam over `package:camera`. Camera providers opt
  out of Riverpod's automatic retry, so failures surface once with an explicit retry. Settings use a
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

Camera tests drive the real `CameraController` against an in-memory
`CameraPlatform` fake (`test/features/camera/fakes`), covering default lens selection,
switching, capture concurrency, lifecycle release/reopen, error states and the
permission screens.

---

## Reference overlay

Tap the gallery button left of the shutter to choose one reference image. It is drawn
between the live preview and the camera controls, so it can never cover the shutter,
flash, zoom or switch buttons.

| Control | Behaviour |
|---|---|
| Opacity tab | Slider 0–100% with the exact percentage; changing it never moves the image |
| 25 / 50 / 75 / 100% | Opacity presets; ↺ resets to the default opacity from Settings |
| Drag / pinch / two-finger twist | Move, resize and rotate (anywhere on the preview while unlocked); rotation snaps to quarter turns within 4° |
| Frame tab: Fit · Fill · Center | Whole image visible · covers the screen, cropping edges (the only mode that crops) · original pixel size; all keep the aspect ratio |
| Reset position | Undoes drag, pinch and rotation within the current mode |
| Lock | Freezes the overlay; camera tap-to-focus and pinch-zoom work again |
| Eye | Hide / show without losing any settings |
| Trash | Remove the image and free its memory |
| Minimize | Tap the handle on top of the tray (or flick it down) to shrink it to a small chip showing the opacity, lock and hidden state; tap the chip (or flick up) to restore it on the same tab |

Notes:

- **The overlay is never part of the photo.** Capture saves exactly what the camera
  produced; a test compares the saved bytes with the camera output.
- Images are decoded once at no more than 2048 px on the longest side, so a 48 MP photo
  costs ~12 MB of GPU memory rather than ~190 MB. EXIF orientation is applied. Unreadable
  or unsupported files show a message and keep the current image.
- Position is stored as a fraction of the screen, so it survives rotation. On short
  (landscape) screens the options start collapsed to the opacity row.
- While the overlay is unlocked, pinching resizes the overlay; to zoom the camera, tap a
  lens stop (0.5× / 1× / 2×…) or drag across the zoom pill, or lock the overlay.

## Capture and saving

Tap the shutter to capture through the active `CameraController`. The camera's own
file is written to the system photo library byte for byte — no resize, no
re-encode — and the app stays on the live preview. There is no review screen and
nothing to dismiss: the photo is already in the gallery when the flash clears.

The reference overlay is a guide only. It is never composited into the photo, and
a test compares the saved bytes with the camera's output. Saving requests the photo
library permission only at that moment, with a rationale sheet first, and reports
success or failure in a message; the shutter is guarded while a capture is in
flight, so repeated taps cannot save twice.

## Brand assets

The logo is a "V" made of two layers, an amber arm and a cream arm crossing at
the vertex, echoing a reference lined up over the live view. Every asset (master
SVGs in `assets/branding/`, the in-app mark, Android legacy/adaptive/themed
launcher icons, the iOS AppIcon set and both launch screens) is generated from one
definition:

```bash
pip install pillow
python tool/brand/generate_brand_assets.py
```

