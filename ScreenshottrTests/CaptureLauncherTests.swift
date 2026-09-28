import XCTest
import Combine

final class CaptureLauncherTests: XCTestCase {
    func testModesPreserveSystemDestinationAndAllowToolbarChoices() {
        for mode in CaptureMode.allCases {
            XCTAssertTrue(mode.arguments.contains("-p"))
            XCTAssertTrue(mode.arguments.contains("-U"))
            XCTAssertFalse(mode.arguments.contains("-s"))
        }
        XCTAssertEqual(CaptureMode.recording.arguments.last, "video")
        XCTAssertEqual(CaptureMode.screenshot.arguments.last, "window")
        XCTAssertEqual(CaptureMode.selectedArea.arguments.last, "selection")
    }

    @MainActor
    func testDuplicateRequestsAreIgnoredAndCompletionAllowsRelaunch() async {
        var launches = 0
        let launcher = CaptureLauncher(executableURL: URL(fileURLWithPath: "/bin/sleep")) { _ in
            launches += 1
            return ["0.1"]
        }
        for expected in 1...2 {
            let finished = expectation(description: "Capture completes")
            let observation = launcher.$isActive.dropFirst().filter { !$0 }.sink { _ in finished.fulfill() }
            launcher.launch(.recording)
            launcher.launch(.selectedArea)
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
        launcher.launch(.screenshot)
        await fulfillment(of: [failed], timeout: 3)
        XCTAssertFalse(launcher.isActive)
    }

    @MainActor
    func testCancellationDoesNotShowAnError() async {
        let launcher = CaptureLauncher(executableURL: URL(fileURLWithPath: "/usr/bin/false")) { _ in [] }
        launcher.onFailure = { _ in XCTFail("Cancellation should be silent") }
        let finished = expectation(description: "Cancellation resets busy state")
        let observation = launcher.$isActive.dropFirst().filter { !$0 }.sink { _ in finished.fulfill() }
        launcher.launch(.selectedArea)
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertFalse(launcher.isActive)
        withExtendedLifetime(observation) {}
    }
}
