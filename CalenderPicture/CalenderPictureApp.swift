//
//  CalenderPictureApp.swift
//  CalenderPicture
//
//  Created by harumi.sagawa on 2026/10/23.
//

import RealityKit
import SwiftData
import SwiftUI

@main
struct CalenderPictureApp: App {
    init() {
        WanderComponent.registerComponent()
        WanderSystem.registerSystem()
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
        }
        // UI テストでは起動引数 -inMemoryStore で毎回空の保存先を使う
        .modelContainer(for: DiaryEntry.self, inMemory: ProcessInfo.processInfo.arguments.contains("-inMemoryStore"))
    }
}
