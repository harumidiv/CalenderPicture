//
//  CalenderPictureApp.swift
//  CalenderPicture
//
//  Created by harumi.sagawa on 2026/10/23.
//

import SwiftData
import SwiftUI

@main
struct CalenderPictureApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // UI テストでは起動引数 -inMemoryStore で毎回空の保存先を使う
        .modelContainer(for: DiaryEntry.self, inMemory: ProcessInfo.processInfo.arguments.contains("-inMemoryStore"))
    }
}
