# KC Gallery Viewer

<p align="center">
  <img src="assets/images/Icon.png" alt="KC Gallery Viewer Icon" width="180" />
</p>

<p align="center">
  <strong>Cross-platform Flutter client for Kemono & Coomer mirrors</strong><br/>
  Browse creators, view media, and manage downloads in one app.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart" alt="Dart" />
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-lightgrey" alt="Platforms" />
  <img src="https://img.shields.io/badge/Status-Active-success" alt="Status" />
</p>

## Overview

**KC Gallery Viewer** is a multi-platform Flutter app to browse, search, and download media from Kemono and Coomer mirror services.

### Highlights
- Fast masonry gallery browsing
- Fullscreen image/video viewing
- Download manager with progress tracking
- Search, filters, bookmarks, and history
- Caching and offline-friendly behavior

## Architecture

```text
lib/
 ├── data/             # Data sources and services
 ├── domain/           # Core entities and business models
 ├── presentation/     # UI screens, widgets, providers
 └── utils/            # Shared helpers
```

## Tech Stack

| Category | Technology |
|---|---|
| Framework | Flutter >= 3.10 |
| Language | Dart >= 3.10 |
| State management | Provider |
| Networking | Dio / HTTP |
| Media | CachedNetworkImage, Chewie, video_player |
| Analytics/Crash reporting | Firebase Analytics, Firebase Crashlytics |

## Platform Support

| Platform | Supported |
|---|---|
| Android | ✅ |
| iOS | ✅ |
| Web | ✅ |
| Windows | ✅ |
| macOS | ✅ |
| Linux | ✅ |

> Availability depends on your local Flutter toolchain setup.

## Getting Started

### Prerequisites
- Flutter SDK 3.10+
- Dart SDK 3.10+
- Android SDK (Android builds)
- Xcode (iOS/macOS builds)

### Setup

```bash
git clone https://github.com/IR2816/K-C-Gallery-Viewer-CoMake.git
cd K-C-Gallery-Viewer-CoMake
flutter pub get
```

### Run

```bash
flutter run
```

Examples:

```bash
flutter run -d android
flutter run -d chrome
flutter run -d windows
```

### Build

```bash
flutter build apk --release
flutter build ios --release
flutter build web --release
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

## Download Notes

- Downloads are saved to **KC Download** inside your device Downloads folder.
- On Android, storage permission is required at runtime.
- Some media servers require valid request headers (referer/origin); the app handles this for in-app downloads.

## Development

Before committing:

```bash
flutter format .
flutter analyze
```

## CI/CD — Automated APK Builds

The GitHub Actions workflow (`.github/workflows/build-apk.yml`) automatically builds and releases a signed APK on every tag push (`v*.*.*`).

### Setting Up Release Signing (Recommended)

Properly signed APKs allow over-the-air upgrades (new versions install over old ones).

**Step 1 — Generate a keystore locally (one-time):**

```bash
keytool -genkey -v -keystore ~/kc-gallery-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias kc_gallery_key
```

**Step 2 — Encode the keystore to base64:**

```bash
base64 ~/kc-gallery-release.jks
```

**Step 3 — Add these four secrets to GitHub Settings → Secrets → Actions:**

| Secret name | Value |
|---|---|
| `KEYSTORE_BASE64` | Base64 output from Step 2 |
| `KEYSTORE_ALIAS` | `kc_gallery_key` |
| `KEYSTORE_PASSWORD` | Keystore password chosen in Step 1 |
| `KEYSTORE_KEY_PASSWORD` | Key password chosen in Step 1 |

Once all four secrets are set, every tagged release will produce a properly signed APK.

### Releasing a New Version

```bash
git tag v1.1.2
git push origin v1.1.2
```

GitHub Actions will build the APK and attach it to a new GitHub Release automatically.

> **Without signing secrets:** The workflow still succeeds but produces a debug-signed APK (not upgradeable over a release-signed build).

## Security & Privacy

- No API keys are stored in the repository.
- Do not commit private tokens/endpoints.
- Keep secrets in environment variables or secure platform storage.
- The keystore file (`*.jks`, `android/keystore/`) and `android/key.properties` are excluded from version control via `.gitignore`.

## Third-Party Services

This app uses public Kemono/Coomer mirror endpoints and is not affiliated with those services.
Users are responsible for complying with local laws, content ownership rules, and service terms.

## License

MIT License. See [LICENSE](LICENSE).
