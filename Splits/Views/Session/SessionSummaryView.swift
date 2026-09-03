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
                    SummaryStatsRow(
                        distance: summary.totalDistance,
                        movingTime: summary.movingTime,
                        averagePace: summary.averagePace,
                        unit: unit
                    )
                    if let goals = GoalSummary.compute(for: summary.laps) {
                        LabeledContent("목표 달성", value: "\(goals.met) / \(goals.total)")
                    }
                }

                Section("구간") {
                    if summary.laps.isEmpty {
                        Text("기록된 구간이 없어요.")
                            .foregroundStyle(.secondary)
                    } else {
                        LapTableHeader(numberTitle: LapTableLayout.isGrouped(summary.laps) ? "세트" : "#")
                    }
                    ForEach(LapTableLayout.rows(for: summary.laps)) { row in
                        LapRow(
                            lap: row.lap,
                            unit: unit,
                            highlight: highlight(for: row.lap),
                            number: row.number,
                            startsSet: row.startsSet
                        )
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
