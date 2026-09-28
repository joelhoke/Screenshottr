import AppKit
import SwiftUI

@main
struct ScreenshottrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var capture = CaptureLauncher()
    @StateObject private var loginItem = LoginItemController()

    var body: some Scene {
        MenuBarExtra {
            CaptureMenu(capture: capture, loginItem: loginItem)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 27, height: 18)
                .accessibilityLabel("Screenshottr")
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

private struct CaptureMenu: View {
    @ObservedObject var capture: CaptureLauncher
    @ObservedObject var loginItem: LoginItemController

    var body: some View {
        Button("Open Capture Toolbar…") { capture.launch(.toolbar) }
            .disabled(capture.isActive)

        Divider()

        Button("Record Screen…") { capture.launch(.recording) }
            .disabled(capture.isActive)
        Button("Screenshot…") { capture.launch(.screenshot) }
            .disabled(capture.isActive)
        Button("Capture Selected Area…") { capture.launch(.selectedArea) }
            .disabled(capture.isActive)

        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { loginItem.isEnabled },
            set: { loginItem.setEnabled($0) }
        ))
        .disabled(loginItem.isUpdating)

        if loginItem.needsApproval {
            Button("Allow in Login Items…") { loginItem.openSettings() }
        }

        Divider()

        Button("Quit Screenshottr") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
            .onAppear {
                loginItem.refresh()
                capture.onFailure = { showAlert(title: "Capture Unavailable", message: $0) }
                loginItem.onFailure = { showAlert(title: "Launch at Login", message: $0) }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
                loginItem.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                loginItem.refresh()
            }
    }

    private func showAlert(title: String, message: String) {
        // Menu-only apps have no window on which to attach a SwiftUI alert.
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
