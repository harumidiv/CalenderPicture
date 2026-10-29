//
//  RegistrationUITests.swift
//  CalenderPictureUITests
//
//  シミュレータに最初から入っている写真を使って、登録の流れを通しで確かめる。
//

import XCTest

final class RegistrationUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-paintStyle", "crayon", "-inMemoryStore"]
        app.launch()
        openCalendar()
    }

    /// 日付のピルを押してカレンダーのシートを開く
    func openCalendar() {
        let pill = app.buttons["card-date"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        pill.tap()
        // シートが開くアニメーション中のタップは無視されるので、開ききるまで待つ
        let close = app.buttons["calendar-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: close)
        waitForExpectations(timeout: 5)
        sleep(1)
    }

    /// 環境変数 SCREENSHOT_DIR があれば、そこにスクリーンショットを書き出す（目視確認用）
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

    func dayKey(_ day: Int) -> String {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        return String(format: "day-%04d-%02d-%02d", now.year!, now.month!, day)
    }

    /// 写真ピッカーで左上の写真を選ぶ。ピッカーは別プロセスで要素が取れないため、画面座標でタップする
    func pickFirstPhoto() {
        sleep(3)  // ピッカーの表示を待つ
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 66, dy: 380)).tap()
    }

    func testRegisterPhotoShowsThumbnail() {
        let cell = app.buttons[dayKey(5)]
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertEqual(cell.value as? String, "未登録")
        cell.tap()

        pickFirstPhoto()

        let register = app.buttons["registration-register"]
        XCTAssertTrue(register.waitForExistence(timeout: 10))
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: register)
        waitForExpectations(timeout: 30)
        saveScreenshot("registration-ready")

        register.tap()
        XCTAssertTrue(register.waitForNonExistence(timeout: 5))
        XCTAssertEqual(cell.value as? String, "登録済み")
        saveScreenshot("calendar-after-registration")
    }

    func testRegisteredPhotoSurvivesRelaunch() {
        app.terminate()
        app.launchArguments = ["-paintStyle", "crayon", "-resetStore"]
        app.launch()
        openCalendar()

        let cell = app.buttons[dayKey(7)]
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertEqual(cell.value as? String, "未登録")
        cell.tap()
        pickFirstPhoto()
        let register = app.buttons["registration-register"]
        XCTAssertTrue(register.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: register)
        waitForExpectations(timeout: 30)
        register.tap()
        XCTAssertTrue(register.waitForNonExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["-paintStyle", "crayon"]
        app.launch()
        openCalendar()
        let relaunchedCell = app.buttons[dayKey(7)]
        XCTAssertTrue(relaunchedCell.waitForExistence(timeout: 5))
        XCTAssertEqual(relaunchedCell.value as? String, "登録済み")
    }

    func testCancelDoesNotSave() {
        let cell = app.buttons[dayKey(6)]
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        pickFirstPhoto()

        let cancel = app.buttons["registration-cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        // シートが開くアニメーション中のタップは無視されるので、押せる状態になるまで待つ
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: cancel)
        waitForExpectations(timeout: 5)
        sleep(1)
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        XCTAssertEqual(cell.value as? String, "未登録")
    }
}
