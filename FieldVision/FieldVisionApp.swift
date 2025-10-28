//
//  FieldVisionApp.swift
//  FieldVision
//
//  Created by Steven Fernandez on 10/10/25.
//

import SwiftUI
import SwiftData

@main
struct FieldVisionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Project.self, LogEntry.self, DailyReport.self, UserSettings.self])
    }
}
