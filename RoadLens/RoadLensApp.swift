//
//  RoadLensApp.swift
//  RoadLens
//
//  Created by alina on 07.06.2026.
//

import SwiftUI
import SwiftData

@main
struct RoadLensApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [SignModel.self, QuestionModel.self])
    }
}
