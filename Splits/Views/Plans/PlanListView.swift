//
//  PlanListView.swift
//  Splits
//

import SwiftData
import SwiftUI

struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IntervalPlan.createdAt) private var plans: [IntervalPlan]
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue
    @State private var activePlan: IntervalPlan?
    @State private var isCreating = false

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    ContentUnavailableView {
                        Label("플랜이 없어요", systemImage: "figure.run")
                    } description: {
                        Text("첫 인터벌 플랜을 만들어 보세요.")
                    } actions: {
                        Button("플랜 만들기", action: addPlan)
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(plans) { plan in
                            NavigationLink(value: plan) {
                                PlanRow(plan: plan, unit: unit)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    activePlan = plan
                                } label: {
                                    Label("시작", systemImage: "play.fill")
                                }
                                .tint(Color("Run"))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    modelContext.delete(plan)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                                Button {
                                    plan.duplicate(into: modelContext)
                                } label: {
                                    Label("복제", systemImage: "doc.on.doc")
                                }
                                .tint(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("플랜")
            .navigationDestination(for: IntervalPlan.self) { plan in
                PlanDetailView(plan: plan)
            }
            .fullScreenCover(item: $activePlan) { plan in
                SessionView(plan: plan)
            }
            .sheet(isPresented: $isCreating) {
                PlanEditorView(plan: nil)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addPlan) {
                        Label("새 플랜", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func addPlan() {
        isCreating = true
    }
}

struct PlanRow: View {
    let plan: IntervalPlan
    let unit: DistanceUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(plan.name)
                .font(.headline)
            Text(Formatters.planSummary(plan.blueprint, unit: unit))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    PlanListView()
        .modelContainer(for: [IntervalPlan.self, Segment.self, Workout.self, Lap.self], inMemory: true)
}
