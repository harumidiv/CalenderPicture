//
//  CardUITests.swift
//  CalenderPictureUITests
//
//  サンプル（今月の 3・10・17 日と今日）を登録した状態で、カードの裏返し・めくり・削除を確かめる。
//

import XCTest

final class CardUITests: XCTestCase {
    var app: XCUIApplication!
    let calendar = Calendar.current

    /// SampleEntries と同じ日（昇順）
    var sampleDays: [Int] {
        Set([3, 10, 17, calendar.component(.day, from: Date())]).sorted()
    }

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-seedSampleEntries"]
        app.launch()
        // サンプルの変換が終わるまで待つ
        let last = app.buttons[dayKey(sampleDays.last!)]
        XCTAssertTrue(last.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "value == '登録済み'"), evaluatedWith: last)
        waitForExpectations(timeout: 60)
    }

    func dayKey(_ day: Int) -> String {
        let now = calendar.dateComponents([.year, .month], from: Date())
        return String(format: "day-%04d-%02d-%02d", now.year!, now.month!, day)
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

    func waitForValue(_ element: XCUIElement, _ value: String) {
        expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: element)
        waitForExpectations(timeout: 5)
    }

    func waitForDate(day: Int) {
        let date = app.staticTexts["card-date"]
        expectation(for: NSPredicate(format: "label ENDSWITH %@", "月\(day)日"), evaluatedWith: date)
        waitForExpectations(timeout: 5)
    }

    /// 一番上のカード（山の下のカードは読み上げの対象外なので1枚だけ見つかる）
    var visibleCard: XCUIElement { app.buttons["card"] }

    /// カードの山
    var pager: XCUIElement { app.otherElements["card-pager"] }

    func testFlipAndSwipe() {
        app.buttons[dayKey(10)].tap()
        waitForDate(day: 10)

        XCTAssertTrue(app.buttons["card"].waitForExistence(timeout: 5))
        let card = visibleCard
        XCTAssertEqual(card.value as? String, "front")
        saveScreenshot("card-front")

        card.tap()
        waitForValue(card, "back")
        sleep(1)  // 回転アニメーションの完了を待つ
        saveScreenshot("card-back")

        // 左にスワイプすると次の登録済みの日（17日）へ
        pager.swipeLeft()
        waitForDate(day: 17)
        sleep(1)
        saveScreenshot("card-after-swipe")
        XCTAssertEqual(visibleCard.value as? String, "front")

        // 戻ると、裏返していた 10 日のカードは表に戻っている
        pager.swipeRight()
        waitForDate(day: 10)
        sleep(1)
        XCTAssertEqual(visibleCard.value as? String, "front")
    }

    func testDeckWrapsAroundInfinitely() {
        let days = sampleDays
        app.buttons[dayKey(days[0])].tap()
        waitForDate(day: days[0])
        // 最初の日の前は最後の日（山の一番後ろのカードが上に来る）
        pager.swipeRight()
        waitForDate(day: days.last!)
        // 最後の日の次は最初の日に戻る
        pager.swipeLeft()
        waitForDate(day: days[0])
        // 何周でもめくれる
        for day in days.dropFirst() + [days[0]] {
            pager.swipeLeft()
            waitForDate(day: day)
        }
    }

    func testRapidSwipesAreNotDropped() {
        let days = sampleDays
        app.buttons[dayKey(days[0])].tap()
        waitForDate(day: days[0])
        // 続けて払っても、1回も取りこぼさずに1枚ずつめくれる
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.45))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.45))
        for _ in 0..<3 {
            start.press(forDuration: 0.01, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
        }
        waitForDate(day: days[3 % days.count])
    }

    func testDeleteMovesToNeighborThenCloses() {
        let days = sampleDays
        app.buttons[dayKey(days[0])].tap()
        waitForDate(day: days[0])

        for (index, day) in days.enumerated() {
            waitForDate(day: day)
            app.buttons["card-delete"].tap()
            // iOS 26 の確認ダイアログでは同じボタンが2つ見つかるので最初のものを押す
            let confirm = app.buttons["card-delete-confirm"].firstMatch
            XCTAssertTrue(confirm.waitForExistence(timeout: 5))
            confirm.tap()
            if index < days.count - 1 {
                waitForDate(day: days[index + 1])
            }
        }

        // 最後の1件を消したらカードが閉じてカレンダーに戻り、すべて未登録になる
        XCTAssertTrue(app.buttons["card-close"].waitForNonExistence(timeout: 5))
        for day in days {
            XCTAssertEqual(app.buttons[dayKey(day)].value as? String, "未登録")
        }
    }
}
