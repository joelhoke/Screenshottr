# Verification

Environment: macOS 26.5.1, Xcode 26.6, Apple Silicon. Checked September 28, 2026.

## Automated and local checks

- Oversized menu bar icon fix: Debug and Release builds succeeded. Loaded the compiled Release asset using AppKit and asserted its native size is exactly 27 × 18 points with template rendering enabled (previously 383 × 255). The status-item label now also receives an explicitly sized NSImage instead of relying on SwiftUI sizing modifiers. Release signature verification passed. The color app icon is unchanged.
- App artwork update: Debug and Release builds succeeded with the supplied color image in all required macOS app icon sizes. Confirmed the built bundle’s `CFBundleIconFile` and `CFBundleIconName` point to `AppIcon`, visually inspected the compiled `.icns`, and verified the Release signature. The menu bar SVG and its rendering code are unchanged.
- Toolbar/icon update: Release and Debug test builds succeeded; all four tests passed again, including the general toolbar’s lack of a starting-mode override. Loaded the compiled SVG asset through AppKit, confirmed its template flag, and visually inspected a rendered preview. Native automation still times out when targeting this menu-only app, so live menu/icon and toolbar interaction checks remain pending.
- Debug app and test bundle compiled for arm64 and x86_64.
- Release build succeeded. `lipo -archs` confirmed both arm64 and x86_64; `codesign --verify --strict` passed for the locally signed Release app.
- `xcrun xctest build/Build/Products/Debug/ScreenshottrTests.xctest`: **4 tests passed, 0 failures**. Covers capture arguments, duplicate requests (including menu-dismissal delay), completion and relaunch, cancellation, and actionable launch failures.
- Project and source Info.plist passed `plutil -lint`.
- App launched locally and its process remained running.
- `NSRunningApplication` confirmed `isFinishedLaunching = true` and the accessory activation policy (no Dock presence).
- `LSUIElement = true` is configured; there is no WindowGroup/main window scene.

The initial `xcodebuild test` invocation compiled successfully but its test runner timed out while preparing to run tests. Running the built test bundle directly with `xcrun xctest` succeeded. Xcode 26.6 emits a warning that its XCTest frameworks require macOS 14 when the test target uses the app’s macOS 13 deployment target; this does not change the app’s deployment target. Xcode also reports skipped App Intents metadata because this app has no App Intents dependency.

## System integration checks still required

Desktop automation repeatedly returned `timeoutReached` when inspecting the running app. The following visual/interactive checks could not be completed in this session. Process launch alone does not verify these behaviors. No captures were taken, login registration was not changed, and no logout/reboot was attempted.

| Check | Procedure and expected result |
| --- | --- |
| Menu and Dock | Open the app; verify the supplied camera and selection-outline menu bar icon, all six actions, no Dock icon, and no main window. |
| General toolbar | Choose Open Capture Toolbar…; verify Apple’s full toolbar opens without forcing a screenshot or recording mode. |
| Icon appearance | Verify the supplied icon is legible at menu bar size in light and dark appearance. |
| Recording mode | Choose Record Screen…; verify Apple’s toolbar opens with Record Selected Portion active and Screenshottr’s menu closed. |
| Screenshot mode | Choose Screenshot…; verify Capture Selected Window is active, and full-screen capture is available. |
| Selected area | Choose Capture Selected Area…; verify Capture Selected Portion is active and the selection can be dragged/resized. |
| Cancel and relaunch | Press Escape in each mode, reopen Screenshottr, and launch another mode. No error alert should appear. |
| Duplicate suppression | While the toolbar or a recording is active, reopen Screenshottr; capture actions should be disabled. They should enable after Apple’s capture process exits. |
| Full-screen video | In the recording toolbar, choose Record Entire Screen, record a few seconds, stop via Apple’s menu bar control, and play the saved file. |
| Area video and microphone | Record a selected portion with a microphone chosen in Options; stop and play the saved file, checking picture and audible microphone input. Restore any changed Options afterwards. |
| Screenshot files | Capture an entire screen and a selected portion; inspect the images and verify both use the destination shown in Apple’s Options menu. |
| Preferences | Note the original destination, timer, microphone, and floating thumbnail settings. Open each mode and confirm Screenshottr does not overwrite those values. Apple may remember toolbar mode/area changes. |
| Multiple displays | With two displays attached, select each screen/region and check that capture and recording work on the intended display. |
| Quit/reopen | Quit via Screenshottr’s menu, verify the process exits, reopen, and verify no duplicate icon or stale disabled actions. Finish any recording with Apple’s controls before quitting. |
| Login registration | Install in Applications. Verify the initial checkbox is off, enable it, complete any macOS approval, close/reopen the menu, and confirm the actual state. Quit/reopen the app and verify it persists. Disable it and confirm that state persists too. Leave it off unless desired. |
| Actual login launch | With login launch enabled, log out/in during a convenient session and verify Screenshottr starts. Then disable it if desired. |
| External login changes | Change Screenshottr’s setting in System Settings → General → Login Items, reopen its menu, and confirm its checkbox reflects the system state. |
| macOS 13 compatibility | Build targets macOS 13; runtime validation on a macOS 13 machine remains pending. |

The automated tests deliberately use harmless executable fixtures instead of recording desktop content. They cannot establish microphone availability, file playback, destination behavior, screen recording permissions, or login-time startup.
