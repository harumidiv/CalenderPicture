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
        .modelContainer(for: DiaryEntry.self)
    }
}
