//
//  MySignsView.swift
//  RoadLens
//
//  Created by alina on 08.06.2026.
//

import SwiftUI
import SwiftData

struct MySignsView: View {
    
    @Query(sort: \SignModel.timestamp, order: .reverse) var signs: [SignModel]
    @Query var allQuestions: [QuestionModel]
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            List {
                if signs.isEmpty {
                    ContentUnavailableView("Немає розпізнаних знаків", systemImage: "magnifyingglass", description: Text("Розпізнані знаки з'являться тут після використання камери"))
                } else {
                    Section("Історія розпізнавань") {
                        ForEach(signs) { sign in
                            NavigationLink(destination: TestSessionView(topic: sign.classOfSign)) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(sign.classOfSign)
                                            .font(.headline)
                                        Text(sign.timestamp.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if sign.isTestPassed {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteSigns)
                    }
                }
            }
            .navigationTitle("RoadLens")
        }
    }
    
    private func deleteSigns(offsets: IndexSet) {
        for index in offsets {
            let signToDelete = signs[index]
            let topic = signToDelete.classOfSign
            
            for question in allQuestions where question.topic == topic {
                modelContext.delete(question)
            }
            
            modelContext.delete(signToDelete)
        }
    }
}

#Preview {
    MySignsView()
}
