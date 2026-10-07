//
//  SummaryPage.swift
//  SplitsWatch
//
//  세션이 끝난 직후. 저장하면 iPhone 기록으로 보내고, 설정에 따라 건강 앱에도 남긴다.
//

import SwiftUI

struct SummaryPage: View {
    let summary: WorkoutSummary
    let unit: DistanceUnit
    let onSave: () async -> Void
    let onDiscard: () -> Void

    @State private var isSaving = false
    @State private var confirmDiscard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(summary.planName)
                    .font(.headline)
                    .lineLimit(2)

                Value(text: Formatters.distance(summary.totalDistance, unit: unit), label: "거리", tint: StepKind.run.tint)
                Value(text: Formatters.clock(summary.movingTime), label: "시간", tint: .primary)
                Value(text: Formatters.pace(summary.averagePace, unit: unit), label: "평균 페이스", tint: .primary)
                if let goals = GoalSummary.compute(for: summary.laps) {
                    Value(text: "\(goals.met) / \(goals.total)", label: "목표 달성", tint: StepKind.rest.tint)
                }

                Button {
                    isSaving = true
                    Task { await onSave() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("저장")
                    }
                }
                .tint(StepKind.run.tint)
                .disabled(isSaving)
                .padding(.top, 4)

                Button("버리기", role: .destructive) {
                    confirmDiscard = true
                }
                .disabled(isSaving)

                if !summary.laps.isEmpty {
                    Text("구간")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                    ForEach(summary.laps, id: \.index) { lap in
                        LapLine(lap: lap, unit: unit)
                    }
                }
            }
        }
        .confirmationDialog("이 세션을 버릴까요?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("버리기", role: .destructive, action: onDiscard)
            Button("취소", role: .cancel) {}
        }
    }

    private struct Value: View {
        let text: String
        let label: String
        let tint: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(text)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// "RUN 3  1:28  400 m  −0:02"
private struct LapLine: View {
    let lap: LapRecord
    let unit: DistanceUnit

    var body: some View {
        HStack(spacing: 6) {
            Text("\(lap.kind.badge) \(lap.ordinal)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(lap.kind.tint)
                .frame(width: 52, alignment: .leading)
            Text(Formatters.clock(lap.duration))
                .font(.system(size: 13).monospacedDigit())
            Spacer(minLength: 2)
            if let delta = Formatters.goalDelta(lap, unit: unit) {
                Text(delta)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(lap.goalMet == true ? StepKind.rest.tint : StepKind.run.tint)
            } else {
                Text(Formatters.distance(lap.distance, unit: unit))
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
