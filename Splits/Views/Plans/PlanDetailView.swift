//
//  PlanDetailView.swift
//  Splits
//
//  플랜을 펼친 구간 목록과 시작 버튼.
//

import SwiftData
import SwiftUI

struct PlanDetailView: View {
    let plan: IntervalPlan
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue
    @State private var isRunning = false
    @State private var isEditing = false

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }
    private var blueprint: PlanBlueprint { plan.blueprint }
    private var steps: [WorkoutStep] { blueprint.steps() }

    var body: some View {
        List {
            Section {
                LabeledContent("구간 수", value: "\(steps.count)")
                if blueprint.plannedDistance > 0 {
                    LabeledContent("계획 거리", value: Formatters.distance(blueprint.plannedDistance, unit: unit))
                }
                if blueprint.plannedDuration > 0 {
                    LabeledContent("계획 시간", value: Formatters.clock(blueprint.plannedDuration))
                }
                LabeledContent("반복", value: "× \(blueprint.repeatCount)")
            }

            Section("구간") {
                ForEach(steps, id: \.index) { step in
                    HStack(spacing: 12) {
                        Text("\(step.index + 1)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 22, alignment: .trailing)
                        StepBadge(kind: step.kind, text: "\(step.kind.badge) \(step.ordinal)/\(step.ordinalTotal)")
                        Spacer()
                        Text(Formatters.target(step.target, unit: unit))
                            .font(.body.monospacedDigit())
                    }
                }
            }
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("편집") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            PlanEditorView(plan: plan)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isRunning = true
            } label: {
                Label("시작", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(steps.isEmpty)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .fullScreenCover(isPresented: $isRunning) {
            SessionView(plan: plan)
        }
    }
}
