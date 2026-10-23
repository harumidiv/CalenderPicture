# カレンダー写真登録 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 月表示カレンダーに1日1枚の写真をクレヨン画に変換して登録し、カードで裏返し・左右めくりしながら見返せるようにする。

**Architecture:** 日付は `DayKey`（年月日）で扱い、SwiftData の `DiaryEntry` に画像データを保存する。変換は ImageTransrator から移した `CrayonFilter` を、紙つきの絵と透明キャラクターの2つを返すように広げて使う。画面はカレンダー → 登録シート / カードページャーの構成。

**Tech Stack:** SwiftUI, SwiftData, Core Image, Vision, PhotosUI, Swift Testing

**Spec:** `docs/superpowers/specs/2026-10-23-calendar-photo-registration-design.md`

## Global Constraints

- iOS 26.2 以上、`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`、Swift 5 モード（既存設定のまま）
- アプリのソースは `CalenderPicture/`、テストは `CalenderPictureTests/`（どちらもファイルシステム同期グループ。置けばビルド対象）
- 1日1件。同じ日の登録は上書き
- 日付キーは `yyyy-MM-dd` 文字列（時刻・タイムゾーンに依存しない）
- 保存形式: クレヨン画と元写真は JPEG（品質 0.85）、キャラクターは PNG（透明を保つ）
- サイズ: 変換入力 長辺 1200px、元写真 長辺 2048px、キャラクター 長辺 1024px
- キャラクター画像は被写体を切り抜けたときだけ作る
- 変換処理はメインスレッド外で実行する
- UI の文言は日本語
- テスト実行コマンド（以下 `$TEST`）:
  `xcodebuild test -project CalenderPicture.xcodeproj -scheme CalenderPicture -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30`

## Review Focus

- 同じ日に登録し直したとき、件数が増えず上書きされること → Task 3 `saveOverwritesSameDay`
- タイムゾーンが変わっても登録した日がずれないこと → Task 1 `keyIgnoresTimeZoneOfSameComponents`
- 縦向きで撮った写真（EXIF の向き情報つき）が横倒しにならないこと → Task 4 `uprightAppliesOrientation`
- カードで表示中の日を削除したとき、隣の日へ移るか、何もなければカードを閉じること → Task 7 `neighborAfterDeletion`
- 6週にまたがる月（例: 2026年8月、日曜始まり）の最終行が欠けないこと → Task 2 `augustNeedsSixRows`

---

### Task 1: テストターゲットの追加と DayKey

**Files:**
- Modify: `CalenderPicture.xcodeproj/project.pbxproj`（テストターゲット追加）
- Create: `CalenderPicture/Model/DayKey.swift`
- Test: `CalenderPictureTests/DayKeyTests.swift`

**Interfaces:**
- Produces: `nonisolated struct DayKey: Hashable, Comparable, Codable, Sendable { let year: Int; let month: Int; let day: Int }`
  - `init(year: Int, month: Int, day: Int)`
  - `init(date: Date, calendar: Calendar = .current)`
  - `init?(string: String)` … `"2026-10-23"` を解釈。不正な形式なら nil
  - `var string: String` … ゼロ埋めの `yyyy-MM-dd`
  - `func date(in calendar: Calendar = .current) -> Date` … その日の0時
  - `static func today(calendar: Calendar = .current) -> DayKey`

- [ ] **Step 1: 作業ブランチを作る**

Run: `git switch -c feature/calendar-photo-registration`

- [ ] **Step 2: Unit Test ターゲット `CalenderPictureTests` を追加する**

`xcodeproj` gem（インストール済み 1.28.1）の Ruby スクリプトを scratchpad に置いて実行する。内容は次のとおり。
- ターゲット種別は `:unit_test_bundle`、テスト対象（TEST_HOST）はアプリ本体
- ソースは `CalenderPictureTests/` を同期グループとして登録する
- `IPHONEOS_DEPLOYMENT_TARGET = 26.2`、`SWIFT_VERSION = 5.0`、`GENERATE_INFOPLIST_FILE = YES`

gem が同期グループに対応しない場合は、Xcode の File > New > Target > Unit Testing Bundle（Swift Testing）で作るようユーザーに依頼する。
最後に `CalenderPictureTests/` を作成する。

- [ ] **Step 3: 失敗するテストを書く**

```swift
import Foundation
import Testing
@testable import CalenderPicture

struct DayKeyTests {
    @Test func stringIsZeroPadded() {
        #expect(DayKey(year: 2026, month: 3, day: 5).string == "2026-03-05")
    }

    @Test func parsesString() {
        #expect(DayKey(string: "2026-10-23") == DayKey(year: 2026, month: 10, day: 23))
        #expect(DayKey(string: "2026-13-01") == nil)
        #expect(DayKey(string: "abc") == nil)
    }

    @Test func keyIgnoresTimeZoneOfSameComponents() {
        var tokyo = Calendar(identifier: .gregorian); tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var hawaii = Calendar(identifier: .gregorian); hawaii.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
        let key = DayKey(year: 2026, month: 10, day: 23)
        // どのタイムゾーンで 0 時を作っても、同じタイムゾーンで戻せば同じ日になる
        #expect(DayKey(date: key.date(in: tokyo), calendar: tokyo) == key)
        #expect(DayKey(date: key.date(in: hawaii), calendar: hawaii) == key)
    }

    @Test func ordersChronologically() {
        #expect(DayKey(year: 2026, month: 9, day: 30) < DayKey(year: 2026, month: 10, day: 1))
    }
}
```

- [ ] **Step 4: テストを実行して失敗を確認する**

Run: `$TEST`
Expected: `DayKey` が見つからずビルドエラー

- [ ] **Step 5: `CalenderPicture/Model/DayKey.swift` に `DayKey` を実装する**

`init?(string:)` は `-` で3つに分け、`Calendar` で実在する日付かどうかを確かめる。

- [ ] **Step 6: テストを実行して通ることを確認する**

Run: `$TEST`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: コミットする**

```bash
git add CalenderPicture.xcodeproj CalenderPicture/Model CalenderPictureTests
git commit -m "feat: テストターゲットと日付キー DayKey を追加"
```

---

### Task 2: 月グリッドの計算

**Files:**
- Create: `CalenderPicture/Calendar/MonthGrid.swift`
- Test: `CalenderPictureTests/MonthGridTests.swift`

**Interfaces:**
- Consumes: `DayKey`
- Produces: `nonisolated struct MonthGrid { let year: Int; let month: Int }`
  - `init(year: Int, month: Int)`、`init(containing key: DayKey)`
  - `func cells(calendar: Calendar = .current) -> [DayKey?]` … 先頭は週の始まり（`calendar.firstWeekday`）に合わせた nil 埋め。末尾は埋めない
  - `func adding(months: Int) -> MonthGrid`
  - `func weekdaySymbols(calendar: Calendar = .current) -> [String]` … `veryShortStandaloneWeekdaySymbols` を firstWeekday から並べ替えたもの
  - `var title: String` … `"2026年10月"`

- [ ] **Step 1: 失敗するテストを書く**

```swift
struct MonthGridTests {
    func calendar(firstWeekday: Int) -> Calendar {
        var c = Calendar(identifier: .gregorian); c.firstWeekday = firstWeekday; return c
    }

    @Test func octoberStartsOnThursday() {
        let sunday = MonthGrid(year: 2026, month: 10).cells(calendar: calendar(firstWeekday: 1))
        #expect(sunday.prefix(4).allSatisfy { $0 == nil })
        #expect(sunday[4] == DayKey(year: 2026, month: 10, day: 1))
        #expect(sunday.compactMap { $0 }.count == 31)
        let monday = MonthGrid(year: 2026, month: 10).cells(calendar: calendar(firstWeekday: 2))
        #expect(monday[3] == DayKey(year: 2026, month: 10, day: 1))
    }

    @Test func augustNeedsSixRows() {
        let cells = MonthGrid(year: 2026, month: 8).cells(calendar: calendar(firstWeekday: 1))
        #expect(cells.count == 37)  // 先頭6マス + 31日 → 6行
        #expect(cells.last == DayKey(year: 2026, month: 8, day: 31))
    }

    @Test func leapFebruary() {
        #expect(MonthGrid(year: 2028, month: 2).cells(calendar: calendar(firstWeekday: 1)).compactMap { $0 }.count == 29)
    }

    @Test func addingMonthsCrossesYear() {
        #expect(MonthGrid(year: 2026, month: 12).adding(months: 1) == MonthGrid(year: 2027, month: 1))
        #expect(MonthGrid(year: 2026, month: 1).adding(months: -1) == MonthGrid(year: 2025, month: 12))
    }
}
```

（`MonthGrid` は `Equatable` にする）

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `$TEST`
Expected: `MonthGrid` が見つからずビルドエラー

- [ ] **Step 3: `MonthGrid` を実装する**

- [ ] **Step 4: テストを実行して通ることを確認する**

Run: `$TEST`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: コミットする**

```bash
git add CalenderPicture/Calendar CalenderPictureTests/MonthGridTests.swift
git commit -m "feat: 月グリッドの計算を追加"
```

---

### Task 3: 保存モデルとストア

**Files:**
- Create: `CalenderPicture/Model/DiaryEntry.swift`
- Create: `CalenderPicture/Model/DiaryStore.swift`
- Modify: `CalenderPicture/CalenderPictureApp.swift`（`.modelContainer(for: DiaryEntry.self)` を付ける）
- Test: `CalenderPictureTests/DiaryStoreTests.swift`

**Interfaces:**
- Consumes: `DayKey`
- Produces:
  - `@Model final class DiaryEntry`
    - `@Attribute(.unique) var dayKey: String`
    - `@Attribute(.externalStorage) var drawingData: Data`（クレヨン画 JPEG）
    - `@Attribute(.externalStorage) var originalData: Data`（元写真 JPEG）
    - `@Attribute(.externalStorage) var characterData: Data?`（透明キャラクター PNG）
    - `var updatedAt: Date`
    - `var key: DayKey`（`dayKey` から作る計算プロパティ）
  - `nonisolated struct EncodedEntryImages: Sendable { let drawing: Data; let original: Data; let character: Data? }`
  - `@MainActor struct DiaryStore { let context: ModelContext }`
    - `func entry(for key: DayKey) -> DiaryEntry?`
    - `func save(_ images: EncodedEntryImages, for key: DayKey) throws` … あれば上書き、なければ追加
    - `func delete(_ key: DayKey) throws`
    - `func allKeys() -> [DayKey]` … 昇順

- [ ] **Step 1: 失敗するテストを書く**

```swift
@MainActor
struct DiaryStoreTests {
    let store: DiaryStore
    init() throws {
        let container = try ModelContainer(for: DiaryEntry.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        store = DiaryStore(context: container.mainContext)
    }
    let images = EncodedEntryImages(drawing: Data([1]), original: Data([2]), character: nil)
    let day = DayKey(year: 2026, month: 10, day: 23)

    @Test func saveOverwritesSameDay() throws {
        try store.save(images, for: day)
        try store.save(EncodedEntryImages(drawing: Data([9]), original: Data([8]), character: Data([7])), for: day)
        #expect(store.allKeys() == [day])
        #expect(store.entry(for: day)?.drawingData == Data([9]))
        #expect(store.entry(for: day)?.characterData == Data([7]))
    }

    @Test func allKeysAreSorted() throws {
        try store.save(images, for: DayKey(year: 2026, month: 10, day: 25))
        try store.save(images, for: DayKey(year: 2026, month: 9, day: 1))
        try store.save(images, for: day)
        #expect(store.allKeys().map(\.string) == ["2026-09-01", "2026-10-23", "2026-10-25"])
    }

    @Test func deleteRemovesEntry() throws {
        try store.save(images, for: day)
        try store.delete(day)
        #expect(store.entry(for: day) == nil)
    }
}
```

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `$TEST`
Expected: `DiaryStore` などが見つからずビルドエラー

- [ ] **Step 3: `DiaryEntry` と `DiaryStore` を実装し、アプリに `modelContainer` を付ける**

- [ ] **Step 4: テストを実行して通ることを確認する**

Run: `$TEST`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: コミットする**

```bash
git add CalenderPicture/Model CalenderPicture/CalenderPictureApp.swift CalenderPictureTests/DiaryStoreTests.swift
git commit -m "feat: 写真日記の保存モデルとストアを追加"
```

---

### Task 4: クレヨン変換の移植と保存用データの作成

**Files:**
- Create: `CalenderPicture/Crayon/CrayonFilter.swift`（`~/Downloads/ImageTransrator/ImageTransrator/CrayonFilter.swift` をコピーして変更）
- Create: `CalenderPicture/Crayon/UIImage+Upright.swift`（ImageTransrator の `ContentView.swift:100-111` の `uprightCGImage(maxSize:)` を `nonisolated extension`（private を外す）として移す）
- Create: `CalenderPicture/Crayon/EntryImageProcessor.swift`
- Test: `CalenderPictureTests/EntryImageProcessorTests.swift`

**Interfaces:**
- Consumes: `EncodedEntryImages`（Task 3）
- Produces:
  - `nonisolated struct CrayonResult { let drawing: CGImage; let character: CGImage? }`
  - `CrayonFilter.apply(to: CGImage) -> CrayonResult?`（戻り値の型を変更）
  - `UIImage.uprightCGImage(maxSize: CGFloat) -> CGImage?`
  - `nonisolated enum EntryImageProcessor`
    - `static func process(_ image: UIImage) -> EncodedEntryImages?` … 元写真を長辺 2048、変換入力を長辺 1200 にし、`CrayonFilter` で変換してエンコードする。変換に失敗したら nil
    - `static func encode(original: CGImage, crayon: CrayonResult) -> EncodedEntryImages?` … JPEG 品質 0.85、キャラクターは長辺 1024 に縮小した PNG

- [ ] **Step 1: 失敗するテストを書く**

```swift
struct EntryImageProcessorTests {
    /// 中央に円がある w×h の画像。transparent なら背景透明
    func makeImage(width: Int, height: Int, transparent: Bool = false) -> CGImage { /* UIGraphicsImageRenderer で描く */ }

    @Test func uprightAppliesOrientation() {
        let rotated = UIImage(cgImage: makeImage(width: 400, height: 200), scale: 1, orientation: .right)
        let upright = rotated.uprightCGImage(maxSize: 1000)!
        #expect(upright.width == 200 && upright.height == 400)
    }

    @Test func crayonDrawingIs1200LongSide() throws {
        let result = try #require(CrayonFilter.apply(to: makeImage(width: 1600, height: 1200)))
        #expect(max(result.drawing.width, result.drawing.height) == 1200)
    }

    @Test func encodesCharacterAsDownscaledPNGWithAlpha() throws {
        let crayon = CrayonResult(drawing: makeImage(width: 1200, height: 900),
                                  character: makeImage(width: 1200, height: 900, transparent: true))
        let encoded = try #require(EntryImageProcessor.encode(original: makeImage(width: 2048, height: 1536), crayon: crayon))
        let character = try #require(encoded.character.flatMap { UIImage(data: $0)?.cgImage })
        #expect(max(character.width, character.height) == 1024)
        #expect(character.alphaInfo != .none && character.alphaInfo != .noneSkipLast)
        #expect(UIImage(data: encoded.drawing) != nil && UIImage(data: encoded.original) != nil)
    }

    @Test func noCharacterWhenSubjectMissing() throws {
        let crayon = CrayonResult(drawing: makeImage(width: 1200, height: 900), character: nil)
        #expect(try #require(EntryImageProcessor.encode(original: makeImage(width: 800, height: 600), crayon: crayon)).character == nil)
    }
}
```

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `$TEST`
Expected: `CrayonFilter` などが見つからずビルドエラー

- [ ] **Step 3: `CrayonFilter.swift` と `uprightCGImage` を移し、`apply` を `CrayonResult?` を返すように変更する**

変換処理そのものは変えない。変更点は次の2つだけ。
- `foregroundMask` が nil だったか（代わりの四角を使ったか）を覚えておく。
- 最後の `result` を作るのと同じ合成で、背景を `paper` ではなく `CIImage.clear` にした画像を `character` にする。マスクは同じ `roughMask` を使い、範囲は `extent` で切り取る。被写体を切り抜けなかった場合、`character` は nil にする。

- [ ] **Step 4: `EntryImageProcessor` を実装する**

JPEG と PNG の書き出しには `UIImage(cgImage:).jpegData(compressionQuality: 0.85)` と `.pngData()` を使う。縮小は `UIGraphicsImageRenderer`（`format.scale = 1`、`opaque = false`）で行う。

- [ ] **Step 5: テストを実行して通ることを確認する**

Run: `$TEST`
Expected: `** TEST SUCCEEDED **`（シミュレータでは Vision の切り抜きが失敗して代わりの四角になることがある。`crayonDrawingIs1200LongSide` はどちらの経路でも通る）

- [ ] **Step 6: コミットする**

```bash
git add CalenderPicture/Crayon CalenderPictureTests/EntryImageProcessorTests.swift
git commit -m "feat: ImageTransrator のクレヨン変換を移植し、透明キャラクター出力を追加"
```

---

### Task 5: カレンダー画面

**Files:**
- Create: `CalenderPicture/Calendar/CalendarView.swift`
- Create: `CalenderPicture/Calendar/DayCell.swift`
- Create: `CalenderPicture/Model/SampleEntries.swift`（DEBUG のみ。起動引数 `-seedSampleEntries` で、今月の 3日・10日・今日などに `EntryImageProcessor.encode` で作ったダミーを保存する）
- Modify: `CalenderPicture/ContentView.swift`（`CalendarView` を表示）

**Interfaces:**
- Consumes: `MonthGrid`, `DayKey`, `DiaryEntry`（`@Query` で取得）, `DiaryStore`
- Produces:
  - `CalendarView`
    - 未登録の日をタップしたら `onSelectEmptyDay(DayKey)` を呼ぶ
    - 登録済みの日をタップしたら `onSelectEntry(DayKey)` を呼ぶ
    - この2つの処理は Task 6、Task 7 で実装し、ここでは空にしておく

- [ ] **Step 1: カレンダー画面を実装する**

- 見出しは `MonthGrid.title`、その左右に前月・翌月ボタンを置く。グリッドを左右にスワイプしても月を移る。
- 曜日の行を置き、7列の `LazyVGrid` で並べる。
- `DayCell` は日付の数字を表示し、登録済みならクレヨン画のサムネイルを敷く。サムネイルは `UIImage(data:)?.preparingThumbnail(of:)` で作り、`.task` の中で非同期に行う。
- 今日の日付はアクセントカラーの丸で目立たせる。
- 起動時は今月を表示する。

- [ ] **Step 2: ビルドし、シミュレータで見た目を確かめる**

Run: ビルドしてインストールし、`xcrun simctl launch booted harumidiv.CalenderPicture -seedSampleEntries` で起動して `xcrun simctl io booted screenshot` を撮る。
Expected: 今月のグリッドが表示され、サンプルの日にサムネイル、今日に丸がつく。前月・翌月への移動もできる。

- [ ] **Step 3: テストが通ることを確認してコミットする**

Run: `$TEST` → `** TEST SUCCEEDED **`

```bash
git add CalenderPicture
git commit -m "feat: 月表示のカレンダー画面を追加"
```

---

### Task 6: 写真の登録フロー

**Files:**
- Create: `CalenderPicture/Registration/RegistrationView.swift`
- Modify: `CalenderPicture/Calendar/CalendarView.swift`（未登録の日をタップしたら `.photosPicker` → 登録シートを開く）

**Interfaces:**
- Consumes: `EntryImageProcessor.process(_:) -> EncodedEntryImages?`, `DiaryStore.save(_:for:)`
- Produces: `RegistrationView(day: DayKey, item: PhotosPickerItem, onFinish: () -> Void)`（Task 7 の「写真を変更」でも使う）

- [ ] **Step 1: `RegistrationView` を実装する**

- `item.loadTransferable(type: Data.self)` で画像を読み、`Task.detached(priority: .userInitiated)` の中で `EntryImageProcessor.process` を実行する。
- 変換中は `ProgressView("クレヨンで描いています…")` を表示する。
- 変換結果のクレヨン画を表示し、タップで元写真と切り替えて見比べられるようにする。
- ボタンは「登録」（`DiaryStore.save` してから `onFinish`）と「キャンセル」（何も保存しない）の2つ。
- 変換または読み込みに失敗した場合は「写真を変換できませんでした」と表示し、保存はしない。

- [ ] **Step 2: ビルドし、シミュレータで登録できることを確かめる**

シミュレータの写真アプリに入っているサンプル写真を使う。
Expected: 変換したクレヨン画が表示され、「登録」でカレンダーのマスにサムネイルが出る。アプリを再起動しても残っている。

- [ ] **Step 3: テストが通ることを確認してコミットする**

Run: `$TEST` → `** TEST SUCCEEDED **`

```bash
git add CalenderPicture
git commit -m "feat: 写真をクレヨン画に変換して登録するフローを追加"
```

---

### Task 7: カードの表示（裏返し・左右めくり・変更・削除）

**Files:**
- Create: `CalenderPicture/Card/FlipCard.swift`
- Create: `CalenderPicture/Card/CardPagerView.swift`
- Create: `CalenderPicture/Card/CardNavigation.swift`
- Modify: `CalenderPicture/Calendar/CalendarView.swift`（登録済みの日をタップしたら `fullScreenCover` でページャーを開く）
- Test: `CalenderPictureTests/CardNavigationTests.swift`

**Interfaces:**
- Consumes: `DiaryStore.allKeys()`, `DiaryStore.entry(for:)`, `DiaryStore.delete(_:)`, `RegistrationView`
- Produces:
  - `nonisolated enum CardNavigation { static func neighborAfterDeleting(_ key: DayKey, in keys: [DayKey]) -> DayKey? }` … 削除後に表示する日を返す。次の日を優先し、なければ前の日、どちらもなければ nil（カードを閉じる）
  - `FlipCard(front: Image, back: Image)`

- [ ] **Step 1: 失敗するテストを書く**

```swift
struct CardNavigationTests {
    let a = DayKey(year: 2026, month: 10, day: 1)
    let b = DayKey(year: 2026, month: 10, day: 5)
    let c = DayKey(year: 2026, month: 10, day: 9)

    @Test func neighborAfterDeletion() {
        #expect(CardNavigation.neighborAfterDeleting(b, in: [a, b, c]) == c)
        #expect(CardNavigation.neighborAfterDeleting(c, in: [a, b, c]) == b)
        #expect(CardNavigation.neighborAfterDeleting(a, in: [a]) == nil)
    }
}
```

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `$TEST`
Expected: `CardNavigation` が見つからずビルドエラー

- [ ] **Step 3: `CardNavigation` を実装する**

- [ ] **Step 4: テストを実行して通ることを確認する**

Run: `$TEST`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: `FlipCard` と `CardPagerView` を実装する**

**FlipCard**
- タップすると `rotation3DEffect(.degrees(angle), axis: (0, 1, 0), perspective: 0.5)` を 0↔180 度で切り替え、spring アニメーションで回す。
- 角度が 90 度未満なら表（クレヨン画）、以上なら裏（元写真）を表示する。
- 裏の内容には、あらかじめ `.rotation3DEffect(.degrees(180), axis: (0, 1, 0))` をかけておく。こうすると、裏返ったときに写真が左右反転しない。
- カードの見た目は角丸と影。

**CardPagerView**
- `TabView(selection:)` の `.page` スタイルで、`allKeys()` の順にカードを並べる。初期表示はタップした日。
- ページを移ったら、裏返していたカードは表に戻す。
- 上部に日付（例:「2026年10月23日」）と閉じるボタンを置く。
- 「写真を変更」は `.photosPicker` から `RegistrationView` を開き、同じ日に上書きする。
- 「削除」は確認ダイアログを出し、OK なら `DiaryStore.delete` を呼んで `CardNavigation.neighborAfterDeleting` の日へ移る。nil ならページャーを閉じる。

- [ ] **Step 6: ビルドし、シミュレータで操作を確かめる**

Run: `-seedSampleEntries` で起動し、登録済みの日をタップする。
Expected:
- カードが開き、タップで回転して元写真が見える。写真の文字などが左右反転していない。
- 左右スワイプでサンプルの日だけをめくれる。
- 削除すると隣の日に移る。最後の1件を消すとカードが閉じる。

- [ ] **Step 7: テストが通ることを確認してコミットする**

Run: `$TEST` → `** TEST SUCCEEDED **`

```bash
git add CalenderPicture CalenderPictureTests/CardNavigationTests.swift
git commit -m "feat: カードの裏返し・左右めくり・変更・削除を追加"
```

---

### 最後に: 実機での確認（ユーザーに依頼）

- 人やペットの写真で、被写体を切り抜いたクレヨン画になること（Vision はシミュレータで動かないことがある）。
- 被写体を切り抜けた写真では、`characterData` が保存されていること（Xcode のデバッガで確認できる）。
