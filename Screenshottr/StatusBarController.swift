import AppKit
import Combine

/// A single status item keeps the two independent buttons together when moved.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    let captureButton = NSButton()
    let menuButton = NSButton()
    let menu = NSMenu(title: "Screenshottr")

    private let capture: CaptureLauncher
    private let loginItem: LoginItemController
    private let loginMenuItem = NSMenuItem(title: "Launch at Login", action: nil, keyEquivalent: "")
    private let approvalMenuItem = NSMenuItem(title: "Allow in Login Items…", action: nil, keyEquivalent: "")
    private var statusItem: NSStatusItem?
    private var observations = Set<AnyCancellable>()

    init(
        capture: CaptureLauncher = CaptureLauncher(),
        loginItem: LoginItemController = LoginItemController(),
        showFailure: @escaping @MainActor (String, String) -> Void = StatusBarController.showAlert
    ) {
        self.capture = capture
        self.loginItem = loginItem
        super.init()

        let icon = (NSImage(named: "MenuBarIcon")?.copy() as? NSImage)
            ?? NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)!
        icon.size = NSSize(width: 27, height: 18)
        icon.isTemplate = true
        configure(captureButton, image: icon, label: "Open Capture Toolbar", action: #selector(openCaptureToolbar))

        let triangle = NSImage(systemSymbolName: "arrowtriangle.down.fill", accessibilityDescription: nil)!
        triangle.size = NSSize(width: 7, height: 4)
        triangle.isTemplate = true
        configure(menuButton, image: triangle, label: "Screenshottr Menu", action: #selector(openMenu))
        menuButton.setAccessibilityHelp("Launch at Login and Quit Screenshottr")

        menu.autoenablesItems = false
        menu.delegate = self
        loginMenuItem.target = self
        loginMenuItem.action = #selector(toggleLoginItem)
        menu.addItem(loginMenuItem)
        approvalMenuItem.target = self
        approvalMenuItem.action = #selector(openLoginSettings)
        menu.addItem(approvalMenuItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Screenshottr", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        updateLoginMenu()

        // Wire failures at startup, even when the user never opens the app menu.
        capture.onFailure = { showFailure("Capture Unavailable", $0) }
        loginItem.onFailure = { showFailure("Launch at Login", $0) }
        capture.$isActive.sink { [weak self] active in
            self?.captureButton.isEnabled = !active
        }.store(in: &observations)
        loginItem.$status.combineLatest(loginItem.$isUpdating)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLoginMenu() }
            .store(in: &observations)
    }

    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: 57)
        item.autosaveName = "Screenshottr.SplitControls"
        guard let container = item.button else {
            NSStatusBar.system.removeStatusItem(item)
            return
        }
        statusItem = item
        container.title = ""
        container.setAccessibilityRole(.group)
        container.setAccessibilityLabel("Screenshottr")
        container.setAccessibilityChildren([captureButton, menuButton])

        for button in [captureButton, menuButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(button)
        }
        NSLayoutConstraint.activate([
            captureButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            captureButton.topAnchor.constraint(equalTo: container.topAnchor),
            captureButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 39),
            menuButton.leadingAnchor.constraint(equalTo: captureButton.trailingAnchor),
            menuButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            menuButton.topAnchor.constraint(equalTo: container.topAnchor),
            menuButton.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    private func configure(_ button: NSButton, image: NSImage, label: String, action: Selector) {
        button.title = ""
        button.image = image
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.focusRingType = .none
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.target = self
        button.action = action
    }

    @objc private func openCaptureToolbar() {
        capture.launch()
    }

    @objc private func openMenu() {
        menuButton.highlight(true)
        defer { menuButton.highlight(false) }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: menuButton.bounds.minY - 3), in: menuButton)
    }

    func menuWillOpen(_ menu: NSMenu) {
        loginItem.refresh()
        updateLoginMenu()
    }

    private func updateLoginMenu() {
        loginMenuItem.state = loginItem.isEnabled ? .on : .off
        loginMenuItem.isEnabled = !loginItem.isUpdating
        approvalMenuItem.isHidden = !loginItem.needsApproval
    }

    @objc private func toggleLoginItem() {
        loginItem.refresh()
        loginItem.setEnabled(!loginItem.isEnabled)
    }

    @objc private func openLoginSettings() {
        loginItem.openSettings()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private static func showAlert(title: String, message: String) {
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
