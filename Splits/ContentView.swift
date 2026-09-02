//
//  ContentView.swift
//  Splits
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            Tab("플랜", systemImage: "list.bullet.rectangle") {
                PlanListView()
            }
            Tab("기록", systemImage: "clock") {
                HistoryListView()
            }
            Tab("설정", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .task {
            Presets.insertInitialIfNeeded(into: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [IntervalPlan.self, Segment.self, Workout.self, Lap.self], inMemory: true)
}
