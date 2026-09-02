//
//  PlanEditorView.swift
//  Splits
//
//  플랜 만들기·수정. 총 예상치는 편집하는 동안 바로 갱신된다.
//

import SwiftData
import SwiftUI

struct PlanEditorView: View {
    /// nil이면 새 플랜.
    let plan: IntervalPlan?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue

    @State private var draft: PlanDraft
    @State private var editingSegment: SegmentDraft?
    @FocusState private var nameFocused: Bool

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }

    init(plan: IntervalPlan?) {
        self.plan = plan
        _draft = State(initialValue: plan.map { PlanDraft(plan: $0) } ?? PlanDraft.new())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("플랜 이름", text: $draft.name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                }

                Section {
                    ForEach(draft.segments) { segment in
                        Button {
                            editingSegment = segment
                        } label: {
                            SegmentDraftRow(segment: segment, unit: unit)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        draft.segments.remove(atOffsets: offsets)
                    }
                    .onMove { source, destination in
                        draft.segments.move(fromOffsets: source, toOffset: destination)
                    }

                    Button {
                        withAnimation {
                            draft.appendSegment()
                        }
                    } label: {
                        Label("구간 추가", systemImage: "plus.circle.fill")
                    }
                } header: {
                    HStack {
                        Text("구간")
                        Spacer()
                        EditButton()
                            .font(.caption)
                            .textCase(nil)
                    }
                } footer: {
                    Text("탭해서 종류와 목표를 바꿉니다. 편집 모드에서 순서를 옮기거나 지울 수 있어요. 마지막 반복의 끝이 회복이면 세션에서는 빠집니다.")
                }

                Section {
                    Stepper(value: $draft.repeatCount, in: 1...30) {
                        LabeledContent("반복", value: "× \(draft.repeatCount)")
                    }
                } footer: {
                    Text("위 구간 묶음을 몇 번 되풀이할지 정합니다.")
                }

                Section("워밍업 · 쿨다운") {
                    Toggle("워밍업", isOn: $draft.hasWarmup.animation())
                    if draft.hasWarmup {
                        MinutesStepper(title: "워밍업 시간", seconds: $draft.warmupSeconds)
                    }
                    Toggle("쿨다운", isOn: $draft.hasCooldown.animation())
                    if draft.hasCooldown {
                        MinutesStepper(title: "쿨다운 시간", seconds: $draft.cooldownSeconds)
                    }
                }

                Section("예상") {
                    let blueprint = draft.blueprint
                    let steps = blueprint.steps()
                    LabeledContent("구간 수", value: "\(steps.count)")
                    if blueprint.plannedDistance > 0 {
                        LabeledContent("계획 거리", value: Formatters.distance(blueprint.plannedDistance, unit: unit))
                    }
                    if blueprint.plannedDuration > 0 {
                        LabeledContent("계획 시간", value: Formatters.clock(blueprint.plannedDuration))
                    }
                }
            }
            .navigationTitle(plan == nil ? "새 플랜" : "플랜 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        draft.apply(to: plan, in: modelContext)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!draft.isValid)
                }
            }
            .sheet(item: $editingSegment) { segment in
                SegmentEditorView(segment: segment, unit: unit) { updated in
                    if let index = draft.segments.firstIndex(where: { $0.id == updated.id }) {
                        draft.segments[index] = updated
                    }
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                if plan == nil {
                    nameFocused = true
                }
            }
        }
    }
}

struct SegmentDraftRow: View {
    let segment: SegmentDraft
    let unit: DistanceUnit

    var body: some View {
        HStack(spacing: 12) {
            StepBadge(kind: segment.kind)
            Text(segment.kind.koreanName)
            Spacer()
            Text(Formatters.target(segment.target, unit: unit))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

/// 분 단위 스텝퍼. 워밍업·쿨다운은 초 단위까지 고를 필요가 없다.
struct MinutesStepper: View {
    let title: String
    @Binding var seconds: TimeInterval

    var body: some View {
        Stepper(
            value: Binding(
                get: { Int(seconds / 60) },
                set: { seconds = TimeInterval($0 * 60) }
            ),
            in: 1...30
        ) {
            LabeledContent(title, value: "\(Int(seconds / 60))분")
        }
    }
}

#Preview {
    PlanEditorView(plan: nil)
        .modelContainer(for: [IntervalPlan.self, Segment.self, Workout.self, Lap.self], inMemory: true)
}
