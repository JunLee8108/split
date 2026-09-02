//
//  TemplateLibraryView.swift
//  Splits
//
//  내장 템플릿 목록. 고르면 내 플랜으로 복사된다.
//

import SwiftData
import SwiftUI

struct TemplateLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [IntervalPlan]
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue
    @State private var addedNames: Set<String> = []

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }

    private func isAdded(_ template: PlanTemplate) -> Bool {
        addedNames.contains(template.name) || plans.contains { $0.name == template.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.cardSpacing) {
                    ForEach(Presets.templates) { template in
                        TemplateCard(template: template, unit: unit, isAdded: isAdded(template)) {
                            withAnimation(.snappy) {
                                Presets.add(template, into: modelContext)
                                _ = addedNames.insert(template.name)
                            }
                        }
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.vertical, 12)
            }
            .background(Color.screenBackground)
            .navigationTitle("템플릿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct TemplateCard: View {
    let template: PlanTemplate
    let unit: DistanceUnit
    let isAdded: Bool
    let onAdd: () -> Void

    private var blueprint: PlanBlueprint { template.blueprint }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.name)
                        .font(.headline)
                    HStack(spacing: 6) {
                        ForEach(Array(blueprint.segments.prefix(3).enumerated()), id: \.offset) { _, segment in
                            StepBadge(kind: segment.kind, text: "\(segment.kind.badge) \(Formatters.target(segment.target, unit: unit))")
                        }
                        if blueprint.repeatCount > 1 {
                            Text("× \(blueprint.repeatCount)")
                                .font(.system(.caption, design: .monospaced).weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
                Button(action: onAdd) {
                    Label(isAdded ? "추가됨" : "추가", systemImage: isAdded ? "checkmark" : "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .contentShape(Capsule())
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(isAdded ? .secondary : .accentColor)
                .accessibilityLabel(isAdded ? "\(template.name) 다시 추가" : "\(template.name) 추가")
            }

            Text(template.note)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(totalLine)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .card()
    }

    private var totalLine: String {
        var parts = ["\(blueprint.steps().count)구간"]
        if blueprint.plannedDistance > 0 {
            parts.append(Formatters.distance(blueprint.plannedDistance, unit: unit))
        }
        if blueprint.plannedDuration > 0 {
            parts.append(Formatters.clock(blueprint.plannedDuration))
        }
        if let warmup = blueprint.warmupSeconds {
            parts.append("워밍업 \(Int(warmup / 60))분")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    TemplateLibraryView()
        .modelContainer(for: [IntervalPlan.self, Segment.self, Workout.self, Lap.self], inMemory: true)
}
