//
//  PlanDetailView.swift
//  Splits
//
//  플랜을 펼친 구간 목록. 세션 시작 버튼은 Phase 3에서 세션 화면과 함께 붙는다.
//

import SwiftData
import SwiftUI

struct PlanDetailView: View {
    let plan: IntervalPlan
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue

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
    }
}
