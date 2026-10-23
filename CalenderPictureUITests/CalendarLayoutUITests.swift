//
//  CalendarLayoutUITests.swift
//  CalenderPictureUITests
//

import XCTest

final class CalendarLayoutUITests: XCTestCase {
    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    /// 横向きでも、スクロールすれば月末の日をタップできる（6行になる月でも最終行が切れない）
    func testLastDayReachableInLandscape() {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)

        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        let lastDay = Calendar.current.range(of: .day, in: .month, for: Date())!.count
        let cell = app.buttons[String(format: "day-%04d-%02d-%02d", now.year!, now.month!, lastDay)]
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        app.scrollViews.firstMatch.swipeUp()
        sleep(1)
        XCTAssertTrue(cell.isHittable, "横向きで月末の日が画面外に切れている")
    }
}
