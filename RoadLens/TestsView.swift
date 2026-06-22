//
//  TestsView.swift
//  RoadLens
//
//  Created by alina on 08.06.2026.
//

import SwiftUI

struct TestsView: View {
    let topics = [
        "Заборонні знаки",
        "Знак небезпеки",
        "Обов'язкові знаки",
        "Інформаційно-вказівні знаки",
        "Знаки сервісу"
    ]
    
    var body: some View {
        NavigationStack {
            List {
                Section("Тести за темами") {
                    ForEach(topics, id: \.self) { topic in
                        NavigationLink(destination: TestSessionView(topic: topic)) {
                            Label(topic, systemImage: "doc.text.magnifyingglass")
                        }
                    }
                }
            }
            .navigationTitle("Тести")
        }
    }
}

#Preview {
    TestsView()
}
