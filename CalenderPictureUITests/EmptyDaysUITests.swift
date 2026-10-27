//
//  EmptyDaysUITests.swift
//  CalenderPictureUITests
//
//  写真のない日も山に混ぜたとき、空のカードからその日に写真を追加できることを確かめる。
//

import XCTest

final class EmptyDaysUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // 設定は起動引数で上書きする（ボタンで切り替えると保存されて、ほかのテストに残るため）
        app.launchArguments = ["-inMemoryStore", "-showsEmptyDays", "YES"]
        app.launch()
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

    func dateLabel(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year!)年\(parts.month!)月\(parts.day!)日"
    }

    func testAddPhotoFromEmptyDayCard() {
        let empty = app.buttons["card-empty"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["card-date"].label, dateLabel(daysAgo: 0))
        XCTAssertEqual(app.buttons["toggle-empty-days"].value as? String, "オン")
        saveScreenshot("empty-day-card")

        // 右へ払うと前の日（今日が月の1日でなければ昨日、1日なら山の一番後ろの今日に戻る）
        if Calendar.current.component(.day, from: Date()) > 1 {
            app.otherElements["card-pager"].swipeRight()
            let date = app.buttons["card-date"]
            expectation(for: NSPredicate(format: "label == %@", dateLabel(daysAgo: 1)), evaluatedWith: date)
            waitForExpectations(timeout: 5)
            sleep(1)  // めくるアニメーションが終わるまで待つ（途中のタップは山に取られる）
        }

        let card = app.buttons["card-empty"]
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: card)
        waitForExpectations(timeout: 5)
        card.tap()
        sleep(3)  // ピッカーの表示を待つ
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 66, dy: 380)).tap()

        let register = app.buttons["registration-register"]
        XCTAssertTrue(register.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: register)
        waitForExpectations(timeout: 30)
        register.tap()

        // 空のカードがクレヨン画のカードに変わる
        XCTAssertTrue(app.buttons["card"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["card-share"].exists)
        sleep(1)
        saveScreenshot("empty-day-filled")
    }
}
