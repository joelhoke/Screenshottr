import AppKit
import Combine

enum CaptureMode: CaseIterable {
    case recording, screenshot, selectedArea

    var arguments: [String] {
        // -p preserves the destination and other settings from Apple's Options menu.
        // Use documented starting styles; all modes retain the full toolbar.
        let style: String
        switch self {
        case .recording: style = "video"
        case .screenshot: style = "window"
        case .selectedArea: style = "selection"
        }
        return ["-i", "-U", "-p", "-d", "-J", style]
    }
}

@MainActor
final class CaptureLauncher: ObservableObject {
    @Published private(set) var isActive = false
    var onFailure: ((String) -> Void)?

    private var process: Process?
    private let executableURL: URL
    private let arguments: (CaptureMode) -> [String]

    init(
        executableURL: URL = URL(fileURLWithPath: "/usr/sbin/screencapture"),
        arguments: @escaping (CaptureMode) -> [String] = { $0.arguments }
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
    }

    func launch(_ mode: CaptureMode) {
        guard !isActive else { return }
        // Reserve immediately, including the interval while the menu is closing.
        isActive = true
        Task { @MainActor in
            // MenuBarExtra's standard menu dismisses after its action returns.
            // Yield, then allow the closing animation to finish before capture UI.
            try? await Task.sleep(nanoseconds: 200_000_000)
            start(mode)
        }
    }

    private func start(_ mode: CaptureMode) {
        let capture = Process()
        capture.executableURL = executableURL
        capture.arguments = arguments(mode)
        capture.standardOutput = FileHandle.nullDevice
        capture.standardError = FileHandle.nullDevice
        capture.terminationHandler = { [weak self] finished in
            let interrupted = finished.terminationReason == .uncaughtSignal
            Task { @MainActor [weak self] in
                self?.process = nil
                self?.isActive = false
                // Escape may return a nonzero status. Apple's -d option presents
                // capture errors; cancellation must not produce our own alert.
                if interrupted {
                    self?.onFailure?("Apple’s capture tool stopped unexpectedly. Try again, or use Shift–Command–5 to open Apple’s capture controls directly.")
                }
            }
        }
        process = capture
        do {
            try capture.run()
        } catch {
            process = nil
            isActive = false
            onFailure?("Couldn’t open Apple’s capture controls. Try again, or press Shift–Command–5.\n\n\(error.localizedDescription)")
        }
    }
}
