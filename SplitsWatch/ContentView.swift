//
//  ContentView.swift
//  SplitsWatch
//
//  플랜을 고르면 목록 자리에 세션이 들어선다. 모달로 띄우지 않아 달리는 중에 실수로 닫히지 않는다.
//

import SwiftUI

struct ContentView: View {
    @State private var activePlan: ActivePlan?

    var body: some View {
        if let activePlan {
            SessionScreen(blueprint: activePlan.blueprint) {
                self.activePlan = nil
            }
            .id(activePlan.id)
        } else {
            PlanListView { blueprint in
                activePlan = ActivePlan(blueprint: blueprint)
            }
        }
    }
}

private struct ActivePlan: Identifiable {
    let id = UUID()
    let blueprint: PlanBlueprint
}

#Preview {
    ContentView()
}
