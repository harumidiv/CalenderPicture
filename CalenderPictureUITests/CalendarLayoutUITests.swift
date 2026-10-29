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
        app.launchArguments = ["-paintStyle", "crayon", "-inMemoryStore"]
        app.launch()
        app.buttons["card-date"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)

        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        let lastDay = Calendar.current.range(of: .day, in: .month, for: Date())!.count
        let cell = app.buttons[String(format: "day-%04d-%02d-%02d", now.year!, now.month!, lastDay)]
        // グリッドは遅延生成なので、画面外の月末のマスはスクロールしてから現れる
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5))
        app.scrollViews.firstMatch.swipeUp()
        sleep(1)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertTrue(cell.isHittable, "横向きで月末の日が画面外に切れている")
    }

    /// 「前の月を表示」で1か月ずつさかのぼり、さかのぼった月の日もタップできる
    func testShowEarlierMonths() {
        let app = XCUIApplication()
        app.launchArguments = ["-paintStyle", "crayon", "-inMemoryStore"]
        app.launch()
        app.buttons["card-date"].tap()

        func month(_ offset: Int) -> DateComponents {
            Calendar.current.dateComponents([.year, .month], from: Calendar.current.date(byAdding: .month, value: offset, to: Date())!)
        }
        let twoAgo = month(-2), threeAgo = month(-3)
        XCTAssertFalse(app.buttons["open-wander-\(twoAgo.year!)-\(twoAgo.month!)"].exists)

        let earlier = app.buttons["calendar-show-earlier"]
        app.scrollViews.firstMatch.swipeDown()
        app.scrollViews.firstMatch.swipeDown()
        XCTAssertTrue(earlier.waitForExistence(timeout: 5))
        earlier.tap()
        XCTAssertTrue(app.buttons["open-wander-\(twoAgo.year!)-\(twoAgo.month!)"].waitForExistence(timeout: 5))
        let firstDay = app.buttons[String(format: "day-%04d-%02d-01", twoAgo.year!, twoAgo.month!)]
        XCTAssertTrue(firstDay.waitForExistence(timeout: 5))
        XCTAssertTrue(firstDay.isHittable, "さかのぼった月が画面に出ていない")

        app.scrollViews.firstMatch.swipeDown()
        earlier.tap()
        XCTAssertTrue(app.buttons["open-wander-\(threeAgo.year!)-\(threeAgo.month!)"].waitForExistence(timeout: 5))
    }
}
