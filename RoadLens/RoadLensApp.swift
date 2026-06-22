//
//  RoadLensApp.swift
//  RoadLens
//
//  Created by alina on 07.06.2026.
//

import SwiftUI

@main
struct RoadLensApp: App {

    @StateObject private var downloader = ModelDownloader()
    @StateObject private var generativeVM = GenerativeViewModel(
        downloader: ModelDownloader()
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(downloader)
                .environmentObject(generativeVM)
                .onAppear {
                    downloader.downloadIfNeeded()
                }
        }
    }
}
