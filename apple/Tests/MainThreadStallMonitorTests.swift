import XCTest
@testable import Kairumo

@MainActor
final class MainThreadStallMonitorTests: XCTestCase {
    /// 主執行緒卡住超過門檻，恢復之後要留一筆日誌，而且帶著卡之前最後一件事。
    func testAStallIsLoggedWithTheLastBreadcrumb() {
        let monitor = MainThreadStallMonitor.shared
        monitor.start()
        monitor.breadcrumb("unit-test-crumb")
        let before = StartupLogger.shared.entries.count

        Thread.sleep(forTimeInterval: 2.2) // 故意卡住主執行緒
        let deadline = Date().addingTimeInterval(4)
        var found = false
        while Date() < deadline, !found {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            found = StartupLogger.shared.entries.dropFirst(before).contains {
                $0.key == "log_main_stall" && $0.args.contains("unit-test-crumb")
            }
        }
        XCTAssertTrue(found, "卡頓沒有被記錄下來")
    }
}
