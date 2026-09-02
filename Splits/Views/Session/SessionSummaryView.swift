//
//  SessionSummaryView.swift
//  Splits
//
//  세션 종료 직후 시트. 저장할지 버릴지 여기서 정한다.
//

import SwiftUI

struct SessionSummaryView: View {
    let summary: WorkoutSummary
    let unit: DistanceUnit
    let onSave: () -> Void
    let onDiscard: () -> Void

    @State private var confirmDiscard = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top, spacing: 0) {
                        SummaryStat(value: Formatters.distanceValue(summary.totalDistance, unit: unit).value,
                                    label: Formatters.distanceValue(summary.totalDistance, unit: unit).unit)
                        SummaryStat(value: Formatters.clock(summary.movingTime), label: "시간")
                        SummaryStat(value: Formatters.pace(summary.averagePace, unit: unit), label: "평균 페이스")
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("구간") {
                    if summary.laps.isEmpty {
                        Text("기록된 구간이 없어요.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(summary.laps, id: \.index) { lap in
                        LapRow(lap: lap, unit: unit, highlight: highlight(for: lap))
                    }
                }
            }
            .navigationTitle(summary.planName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("삭제", role: .destructive) {
                        confirmDiscard = true
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: onSave)
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog("이 세션을 저장하지 않고 버릴까요?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("버리기", role: .destructive, action: onDiscard)
                Button("취소", role: .cancel) {}
            }
        }
    }

    private func highlight(for lap: LapRecord) -> LapHighlight? {
        LapHighlight.compute(for: summary.laps)[lap.index]
    }
}

private struct SummaryStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2.weight(.medium))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
