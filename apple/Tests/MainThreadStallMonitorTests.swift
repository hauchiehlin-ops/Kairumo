import XCTest
@testable import Kairumo

@MainActor
final class MainThreadStallMonitorTests: XCTestCase {
    /// 主執行緒卡住超過門檻，恢復之後要留一筆日誌，而且帶著卡之前最後一件事。
    func testAStallIsLoggedWithTheLastBreadcrumb() {
        let monitor = MainThreadStallMonitor.shared
        monitor.start()
        monitor.breadcrumb("unit-test-crumb")
        // 讓背景計時器先跑過至少一輪 ping-pong，確立基線
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
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

    /// 卡頓時要能取到主執行緒的堆疊樣本，而且記在日誌裡。
    func testAStallAlsoLogsAStackSample() {
        let monitor = MainThreadStallMonitor.shared
        monitor.start()
        // 讓背景計時器先跑過至少一輪 ping-pong，確立基線
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let before = StartupLogger.shared.entries.count

        Thread.sleep(forTimeInterval: 2.6) // 卡過門檻 + 取樣
        let deadline = Date().addingTimeInterval(4)
        var entry: StartupLogger.LogEntry?
        while Date() < deadline, entry == nil {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            entry = StartupLogger.shared.entries.dropFirst(before).first { $0.key == "log_main_stall_stack" }
        }
        let found = try? XCTUnwrap(entry, "卡頓沒有留下堆疊樣本")
        XCTAssertNotNil(found)
        // 位址欄要有至少兩個偏移（0x…）
        XCTAssertGreaterThanOrEqual(found?.args.last?.split(separator: " ").count ?? 0, 2)
    }
}
