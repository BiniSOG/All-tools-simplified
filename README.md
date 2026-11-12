# Toolbox

An all-in-one utility app for **Android and iOS**, built with Flutter: 27 everyday tools plus 5 mini games in one small, fully offline app.

- **Runs on old phones** – Android 5.0 (2014) and newer, iOS 12 (iPhone 5s) and newer.
- **Native, not a web page** – compiled to ARM code with Flutter's own renderer, so it looks and behaves the same on every device.
- **Offline and private** – no account, no network permission, no ads; everything is stored on the device.

## What's inside

| Section | Tools |
| --- | --- |
| Games | Block Drop (falling-block puzzle), Paddle Pong (vs. computer), Snake, Memory Match, Tic-Tac-Toe |
| Calculators | Calculator, Unit Converter (8 categories), Percentage, Loan / EMI, Tip & Split, BMI, Age & Dates, Number Base |
| Time | Stopwatch with laps, Timer, World Clock |
| Notes & documents | PDF Reader, Notes, To-Do List, Text Tools, Clipboard saver, QR Generator, Morse Code (with light signalling), Password generator |
| Utilities | Flashlight, Compass, Bubble Level, Metal Detector, Paint, Tally Counter, Dice & Random, Color Mixer |

Things that bring people back:

- **Daily streak** counter on the home screen, with a best-streak record.
- **Game of the day** card that rotates daily and challenges you to beat your own best.
- **Personal bests** saved for every game.
- **Favorites** (tap ☆ in any tool) and **Recently used** rows, plus instant **search**.
- The PDF reader **remembers your page** in each document; the stopwatch keeps running while you use other tools.
- Light and dark themes.

## Run it

Install [Flutter 3.32.x](https://docs.flutter.dev/get-started/install), then:

```sh
flutter pub get
flutter run            # on a connected phone or emulator
flutter test           # unit + widget tests
```

Release builds:

```sh
flutter build apk --release        # Android: build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release  # Android: for Google Play
flutter build ipa --release        # iOS: needs a Mac with Xcode and an Apple developer account
```

Every push also builds the Android APK on GitHub Actions (see the **Actions** tab → latest run → *toolbox-android-apk* artifact) and compiles the iOS app.

Before publishing to the stores, set up your own release signing key in `android/app/build.gradle.kts` (it currently signs with the debug key so the APK installs for testing) and change the app id `com.binisog.toolbox` if you want a different one.

## Project layout

```
lib/
  main.dart           app shell, home screen, tool page frame
  registry.dart       the list of all tools (add new ones here)
  core/logic.dart     pure calculation code (unit-tested)
  core/store.dart     on-device storage, high scores, streak
  core/ui.dart        shared widgets
  tools/              calculators, time, text/documents, utilities
  games/              games; block_engine.dart holds the block-puzzle rules
android/, ios/        native projects (flashlight is a few lines of Kotlin/Swift)
test/                 logic tests + a test that opens every tool on a 320×480 screen
```

To add a tool, write a widget in `lib/tools/` and add one `ToolDef(...)` line to `lib/registry.dart`; it then appears on the home screen, in search, and in the test suite automatically.

## Why Flutter 3.32 and pinned plugin versions

Newer Flutter releases require Android 7+, and newer `pdfx` / `sensors_plus` releases require iOS 13+. The versions pinned in `pubspec.yaml` are the newest ones that still support Android 5 and iOS 12. If old-device support stops mattering, they can simply be upgraded.
