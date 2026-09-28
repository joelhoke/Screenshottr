# Screenshottr

A small, native menu bar launcher for Apple’s screenshot and screen recording toolbar. Requires macOS 13 or later. No Dock icon, main window, dependencies, network service, or additional global shortcuts.

## Build and run

Open `Screenshottr.xcodeproj` in Xcode, select the **Screenshottr** scheme and **My Mac**, then Run. The camera/viewfinder icon appears in the menu bar. The project uses local ad hoc signing, so a paid developer account is not required for personal use on this Mac.

Or build from Terminal with Xcode installed:

```sh
xcodebuild -project Screenshottr.xcodeproj -scheme Screenshottr \
  -configuration Release -derivedDataPath build build
open build/Build/Products/Release/Screenshottr.app
```

## Install

1. Quit any running copy of Screenshottr using its menu.
2. In Finder, open `build/Build/Products/Release` and drag **Screenshottr.app** into **Applications**.
3. Open the copy in Applications. Enable **Launch at Login** from its menu if desired.

Keep a single installed copy, and configure login launch from that copy. Launch at Login is off on a fresh install; the app never registers itself automatically. If macOS requires approval, **Allow in Login Items…** opens the appropriate System Settings page. The checkbox is checked only when macOS reports the service as enabled. Existing registration is respected across app launches.

This is a locally signed personal build. Developer ID distribution, notarization, and App Store packaging are not configured.

## Use

| Menu action | Initial Apple toolbar mode |
| --- | --- |
| Record Screen… | Record Selected Portion; choose Record Entire Screen in the toolbar if desired |
| Screenshot… | Capture Selected Window; choose Capture Entire Screen or Capture Selected Portion in the toolbar |
| Capture Selected Area… | Capture Selected Portion; drag or resize the area with Apple’s controls |

All three actions expose Apple’s full toolbar. Use **Options** for the save destination, timer, floating preview, and microphone when recording. Use Apple’s menu bar Stop button to finish recording, or Escape to cancel before capture. System audio is not added by Screenshottr.

Screenshottr passes `-i -U -p -d -J <style>` to `/usr/sbin/screencapture` without a filename. `-p` uses the system’s capture settings and destination; the app does not write screenshot preferences or override the microphone, delay, preview, or output location. Apple may remember changes you make in its toolbar, including the last selected area. Starting styles are the documented `video`, `window`, and `selection` values (`man screencapture`).

The menu closes before the capture tool launches. Capture actions are unavailable while the child process is active, including during recording. The UI remains responsive. Cancellation is silent; process launch failures offer the standard Shift–Command–5 shortcut as recovery, while `screencapture -d` handles capture errors graphically. Quitting Screenshottr does not forcibly terminate Apple’s capture tool or an ongoing recording; finish recordings using Apple’s Stop control.

## Verification

Run the tests:

```sh
xcodebuild -project Screenshottr.xcodeproj -scheme Screenshottr \
  -configuration Debug -derivedDataPath build -destination 'platform=macOS' test
```

Tests exercise real harmless child processes to check duplicate suppression, return to idle, relaunch, silent nonzero cancellation, and launch failure recovery. They also verify that every capture action uses the toolbar and preserves the configured destination. They do not capture the desktop or modify login items.

If Xcode’s test runner times out after building the test bundle, run the tests directly:

```sh
xcrun xctest build/Build/Products/Debug/ScreenshottrTests.xctest
```

For the system integration checks and observed results, see [VERIFICATION.md](VERIFICATION.md).

## Project map

- `ScreenshottrApp.swift`: menu bar scene, menu actions, and native error alerts.
- `CaptureLauncher.swift`: starting modes and asynchronous child process lifecycle.
- `LoginItemController.swift`: [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) registration and actual system status.
- `Info.plist`: `LSUIElement` and app metadata.
- `ScreenshottrTests/`: process lifecycle regression tests.

The app intentionally runs without App Sandbox so it can invoke Apple’s system capture utility. It uses public Apple frameworks and the locally installed command-line tool; there is no custom capture engine, recording indicator, or editor.
