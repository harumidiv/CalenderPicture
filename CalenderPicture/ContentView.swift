//
//  ContentView.swift
//  CalenderPicture
//
//  Created by harumi.sagawa on 2026/10/23.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        CalendarView(
            onSelectEmptyDay: { _ in },
            onSelectEntry: { _ in }
        )
        #if DEBUG
        .task {
            if SampleEntries.isRequested {
                await SampleEntries.seed(into: DiaryStore(context: modelContext))
            }
        }
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: DiaryEntry.self, inMemory: true)
}
