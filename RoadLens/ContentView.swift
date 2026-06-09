//
//  ContentView.swift
//  RoadLens
//
//  Created by alina on 07.06.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MySignsView()
                .tabItem {
                    Label("Мої знаки", systemImage: "house")
                }

            CameraView()
                .tabItem {
                    Label("Камера", systemImage: "camera")
                }

            TestsView()
                .tabItem {
                    Label("Тести", systemImage: "book")
                }
        }
    }
}

#Preview {
    ContentView()
}
