import XCTest
@testable import ModSwitchIME

final class MenuBarIconDebounceTests: XCTestCase {
    func testInternalNotificationDebouncedToSingleUpdate() {
        // Given: a MenuBarApp instance
        let app = MenuBarApp()

        // Allow async initialization + initial icon update to complete
        let initExp = expectation(description: "wait init")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { initExp.fulfill() }
        wait(for: [initExp], timeout: 1.0)

        // Reset debug counter and record baseline
        MenuBarApp.debugResetIconUpdateCount()
        let before = MenuBarApp.debugIconUpdateCount

        // When: fire multiple internal IME switch notifications rapidly
        for _ in 0..<5 {
            NotificationCenter.default.post(
                name: NSNotification.Name("ModSwitchIME.didSwitchIME"),
                object: nil,
                userInfo: ["imeId": "com.apple.keylayout.US"]
            )
        }

        // Then: after debounce, only one additional icon update should be counted
        let exp = expectation(description: "wait debounce")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        let delta = MenuBarApp.debugIconUpdateCount - before
        XCTAssertGreaterThanOrEqual(delta, 1, "At least one debounced icon update is expected")
        XCTAssertLessThan(delta, 3, "Debounce should coalesce rapid notifications to a small number of updates")
        _ = app // keep reference alive for test duration
    }
}
