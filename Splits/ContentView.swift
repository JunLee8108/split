//
//  ContentView.swift
//  Splits
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    /// 콜드 스타트에만 true. 백그라운드에서 돌아올 때는 뷰가 살아 있어 다시 뜨지 않는다.
    @State private var showIntro = true

    var body: some View {
        ZStack {
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

            if showIntro {
                IntroView {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showIntro = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }

            // 인트로가 도는 동안 MapKit을 예열한다. 기록 상세 첫 진입이 부드러워진다.
            MapWarmupView()
                .zIndex(-1)
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
