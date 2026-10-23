//
//  WanderUITests.swift
//  CalenderPictureUITests
//

import XCTest

final class WanderUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-seedSampleEntries"]
        app.launch()
        // サンプルの変換が終わるまで待つ（今日のマスが最後に登録される）
        let day = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let today = app.buttons[String(format: "day-%04d-%02d-%02d", day.year!, day.month!, day.day!)]
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "value == '登録済み'"), evaluatedWith: today)
        waitForExpectations(timeout: 60)
    }

    func saveScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? XCUIScreen.main.screenshot().pngRepresentation
                .write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    func testCharactersWanderInMonthWithCharacters() {
        app.buttons["open-wander"].tap()
        XCTAssertTrue(app.buttons["wander-close"].waitForExistence(timeout: 5))
        sleep(4)  // キャラクターが登場して動き出すのを待つ
        XCTAssertFalse(app.staticTexts["wander-empty"].exists)
        saveScreenshot("wander-1")
        sleep(2)
        saveScreenshot("wander-2")

        app.buttons["wander-close"].tap()
        XCTAssertTrue(app.buttons["open-wander"].waitForExistence(timeout: 5))
    }

    func testEmptyMonthShowsMessage() {
        app.buttons["次の月"].tap()
        app.buttons["open-wander"].tap()
        XCTAssertTrue(app.staticTexts["wander-empty"].waitForExistence(timeout: 5))
    }
}
