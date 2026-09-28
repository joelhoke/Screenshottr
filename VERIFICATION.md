# Verification

Environment: macOS 26.5.1, Xcode 26.6, Apple Silicon. Checked September 28, 2026.

## Current implementation

Screenshottr uses a native AppKit status item with two adjacent buttons: a 27 × 18-point camera image in a 39-point-wide button, and a small chevron in an 18-point-wide button. The camera opens Apple’s full capture toolbar. The arrow opens Launch at Login and Quit Screenshottr, plus the approval shortcut when required. Both buttons stay together as one movable status item. The color app icon is unchanged.

## Automated checks

- Debug build-for-testing succeeded for arm64 and x86_64.
- Release build succeeded for arm64 and x86_64, and strict code signature verification passed.
- `xcrun xctest build/Build/Products/Debug/ScreenshottrTests.xctest`: **6 tests passed, 0 failures**.
- Tests cover preservation of system capture settings and mode, duplicate suppression, completion/relaunch, cancellation, and actionable launch failures.
- Native button tests invoke the camera button’s actual target/action, check that it disables during capture while the arrow stays enabled, verify the simplified menu, and check error delivery before the app menu has ever been opened.
- The compiled menu bar SVG has a native size of 27 × 18 points with template rendering; the status item also explicitly sizes its image. The full-size color app artwork is a separate AppIcon asset.

The tests use harmless child processes and do not install status items, capture the desktop, or modify login registration. They exercise button actions without simulating mouse input on the screen.

The initial project’s `xcodebuild test` runner timed out while preparing tests. Running the built bundle directly with `xcrun xctest` succeeds. Xcode 26.6 warns that its XCTest frameworks require macOS 14 while the test target uses the app’s macOS 13 deployment target; the shipping app still targets macOS 13. Xcode also reports skipped App Intents metadata because this app has no App Intents dependency.

## Interactive checks

Native automation has repeatedly timed out when inspecting this menu-only app. Process launch and automated button tests do not establish the live appearance, pointer hit regions, or Apple toolbar behavior. No recordings, microphone captures, login changes, or logout/reboot tests were performed by the automated tests.

| Check | Procedure and expected result |
| --- | --- |
| Buttons and app lifecycle | Verify one compact camera-and-arrow group, no Dock icon, and no main window. Quit from the arrow menu, reopen, and verify only one group appears. |
| Camera | Click the camera once. Apple’s full capture toolbar should open directly without the Screenshottr menu. |
| Arrow | Click the arrow. Only Launch at Login and Quit Screenshottr should appear, plus Allow in Login Items… if approval is required. It should not start capture. |
| Hit regions and accessibility | Click both sides and their shared boundary; verify each activates only its own action. Check the Open Capture Toolbar and Screenshottr Menu accessibility labels and tooltips. |
| Appearance and positioning | Check both controls in light/dark appearance and confirm they remain together when Command-dragging the status item. |
| Cancel and relaunch | Open the toolbar, press Escape, and click the camera again. No error alert should appear. |
| Duplicate suppression | While the toolbar or a recording is active, camera clicks should not start another process; the arrow should still open the app menu. The camera should enable after capture exits. |
| Full-screen video | Choose Record Entire Screen in Apple’s toolbar, record briefly, stop with Apple’s control, and play the saved file. |
| Area video and microphone | Select a portion and microphone in Apple’s Options, record, stop, and play the file to check picture and audio. Restore changed options afterwards. |
| Screenshot files | Capture an entire screen and a selected portion. Inspect the images and verify they use the destination in Apple’s Options menu. |
| Preferences | Note the destination, timer, microphone, and floating thumbnail settings; confirm opening the toolbar does not overwrite them. Apple may remember toolbar mode/area changes. |
| Multiple displays | With two displays, select each screen/region and check that capture works on the intended display. |
| Login registration | Install in Applications. Verify the checkbox is initially off, enable it, complete any required macOS approval, reopen the menu, and confirm actual state. Quit/reopen and confirm persistence. Disable it afterwards unless desired. |
| Actual login launch | With login launch enabled, log out/in during a convenient session and verify startup. Disable it afterwards if desired. |
| External login changes | Change Screenshottr’s registration in System Settings, reopen the arrow menu, and verify its checkbox reflects the system state. |
| macOS 13 compatibility | The app targets macOS 13; validation on a macOS 13 machine remains pending. |
