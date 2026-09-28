import XCTest
import Combine
import AppKit

final class CaptureLauncherTests: XCTestCase {
    @MainActor
    func testToolbarPreservesSystemDestinationAndMode() async {
        XCTAssertTrue(CaptureLauncher.toolbarArguments.contains("-p"))
        XCTAssertTrue(CaptureLauncher.toolbarArguments.contains("-U"))
        XCTAssertFalse(CaptureLauncher.toolbarArguments.contains("-s"))
        XCTAssertFalse(CaptureLauncher.toolbarArguments.contains("-J"))
    }

    @MainActor
    func testDuplicateRequestsAreIgnoredAndCompletionAllowsRelaunch() async {
        var launches = 0
        let launcher = CaptureLauncher(executableURL: URL(fileURLWithPath: "/bin/sleep")) {
            launches += 1
            return ["0.1"]
        }
        for expected in 1...2 {
            let finished = expectation(description: "Capture completes")
            let observation = launcher.$isActive.dropFirst().filter { !$0 }.sink { _ in finished.fulfill() }
            launcher.launch()
            launcher.launch()
            XCTAssertTrue(launcher.isActive)
            await fulfillment(of: [finished], timeout: 3)
            XCTAssertEqual(launches, expected)
            XCTAssertFalse(launcher.isActive)
            withExtendedLifetime(observation) {}
        }
    }

    @MainActor
    func testLaunchFailureResetsBusyStateAndOffersRecovery() async {
        let launcher = CaptureLauncher(executableURL: URL(fileURLWithPath: "/nonexistent/screenshottr-test"))
        let failed = expectation(description: "Actionable launch error")
        launcher.onFailure = { message in
            XCTAssertTrue(message.contains("Shift–Command–5"))
            failed.fulfill()
        }
        launcher.launch()
        await fulfillment(of: [failed], timeout: 3)
        XCTAssertFalse(launcher.isActive)
    }

    @MainActor
    func testCancellationDoesNotShowAnError() async {
        let launcher = CaptureLauncher(executableURL: URL(fileURLWithPath: "/usr/bin/false")) { [] }
        launcher.onFailure = { _ in XCTFail("Cancellation should be silent") }
        let finished = expectation(description: "Cancellation resets busy state")
        let observation = launcher.$isActive.dropFirst().filter { !$0 }.sink { _ in finished.fulfill() }
        launcher.launch()
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertFalse(launcher.isActive)
        withExtendedLifetime(observation) {}
    }
}

final class StatusBarControllerTests: XCTestCase {
    @MainActor
    func testCameraClickLaunchesOnceAndLeavesSettingsAvailable() async {
        _ = NSApplication.shared
        var launches = 0
        let launcher = CaptureLauncher(executableURL: URL(fileURLWithPath: "/bin/sleep")) {
            launches += 1
            return ["0.1"]
        }
        let controller = StatusBarController(capture: launcher) { _, _ in XCTFail("Unexpected error") }
        let finished = expectation(description: "Capture completes")
        let observation = launcher.$isActive.dropFirst().filter { !$0 }.sink { _ in finished.fulfill() }

        // Exercise the native button's target/action, not just the service.
        controller.captureButton.performClick(nil)
        controller.captureButton.performClick(nil)
        XCTAssertTrue(launcher.isActive)
        XCTAssertFalse(controller.captureButton.isEnabled)
        XCTAssertTrue(controller.menuButton.isEnabled)
        XCTAssertEqual(controller.captureButton.image?.size, NSSize(width: 27, height: 18))
        XCTAssertFalse(controller.menu.items.contains { $0.title.contains("Capture") || $0.title.contains("Record") })
        XCTAssertTrue(controller.menu.items.contains { $0.title == "Launch at Login" })
        XCTAssertTrue(controller.menu.items.contains { $0.title == "Quit Screenshottr" })

        await fulfillment(of: [finished], timeout: 3)
        XCTAssertEqual(launches, 1)
        XCTAssertTrue(controller.captureButton.isEnabled)
        withExtendedLifetime((controller, observation)) {}
    }

    @MainActor
    func testCameraFailureIsReportedWithoutOpeningSettingsMenu() async {
        _ = NSApplication.shared
        let launcher = CaptureLauncher(executableURL: URL(fileURLWithPath: "/nonexistent/screenshottr-test"))
        let failed = expectation(description: "Failure is wired at startup")
        let controller = StatusBarController(capture: launcher) { title, message in
            XCTAssertEqual(title, "Capture Unavailable")
            XCTAssertTrue(message.contains("Shift–Command–5"))
            failed.fulfill()
        }
        controller.captureButton.performClick(nil)
        await fulfillment(of: [failed], timeout: 3)
        XCTAssertTrue(controller.captureButton.isEnabled)
        XCTAssertTrue(controller.menuButton.isEnabled)
        withExtendedLifetime(controller) {}
    }
}
