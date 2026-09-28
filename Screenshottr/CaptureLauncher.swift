import AppKit
import Combine

@MainActor
final class CaptureLauncher: ObservableObject {
    // Full toolbar, system preferences, and no starting-mode or destination override.
    static let toolbarArguments = ["-i", "-U", "-p", "-d"]

    @Published private(set) var isActive = false
    var onFailure: ((String) -> Void)?

    private var process: Process?
    private let executableURL: URL
    private let arguments: () -> [String]

    init(
        executableURL: URL = URL(fileURLWithPath: "/usr/sbin/screencapture"),
        arguments: @escaping () -> [String] = { CaptureLauncher.toolbarArguments }
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
    }

    func launch() {
        guard !isActive else { return }
        // Reserve immediately so rapid clicks cannot start duplicate processes.
        isActive = true
        Task { @MainActor in
            // Let the status button finish its mouse-up highlight before capture UI.
            try? await Task.sleep(nanoseconds: 200_000_000)
            start()
        }
    }

    private func start() {
        let capture = Process()
        capture.executableURL = executableURL
        capture.arguments = arguments()
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
