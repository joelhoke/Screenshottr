import Combine
import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var status = SMAppService.mainApp.status
    @Published private(set) var isUpdating = false
    var onFailure: ((String) -> Void)?

    var isEnabled: Bool { status == .enabled }
    var needsApproval: Bool { status == .requiresApproval }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        guard !isUpdating else { return }
        refresh()
        if enabled && needsApproval {
            SMAppService.openSystemSettingsLoginItems()
            return
        }
        isUpdating = true
        Task { @MainActor in
            defer {
                refresh()
                isUpdating = false
            }
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try await SMAppService.mainApp.unregister()
                }
            } catch {
                onFailure?("Couldn’t change Launch at Login. Install Screenshottr in Applications, then try again. You can also review it in System Settings → General → Login Items.\n\n\(error.localizedDescription)")
            }
        }
    }

    func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
