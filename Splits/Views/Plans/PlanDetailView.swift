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
                if let estimate = Formatters.estimatedDuration(blueprint) {
                    LabeledContent("예상 시간", value: estimate)
                }
                LabeledContent("반복", value: "× \(blueprint.repeatCount)")
            } footer: {
                if blueprint.estimatedDuration.unknownSteps > 0 {
                    Text("목표 시간이 없는 거리 구간 \(blueprint.estimatedDuration.unknownSteps)개는 예상 시간에서 빠졌어요. 구간을 편집해 목표를 넣으면 정확해집니다.")
                }
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
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(Formatters.target(step.target, unit: unit))
                                .font(.body.monospacedDigit())
                            if let goal = step.goalValue {
                                Text("목표 \(Formatters.goal(step.target, goalValue: goal, unit: unit)) · \(Formatters.pace(step.goalPace, unit: unit))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
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
