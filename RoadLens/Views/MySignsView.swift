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
            modelContext.delete(signs[index])
        }
    }
}

#Preview {
    MySignsView()
}
