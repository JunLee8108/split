//
//  HistoryListView.swift
//  Splits
//
//  기록 목록. 상세 화면(랩 테이블, 지도)은 Phase 5.
//

import Foundation
import SwiftData
import SwiftUI

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "아직 기록이 없어요",
                        systemImage: "clock",
                        description: Text("플랜을 골라 첫 세션을 시작하면 여기에 쌓입니다.")
                    )
                } else {
                    List {
                        ForEach(workouts) { workout in
                            WorkoutRow(workout: workout, unit: unit)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                modelContext.delete(workouts[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("기록")
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    let unit: DistanceUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.planName)
                    .font(.headline)
                Spacer()
                Text(workout.startedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                Label(Formatters.distance(workout.totalDistance, unit: unit), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                Label(Formatters.clock(workout.movingTime), systemImage: "stopwatch")
                Label(Formatters.pace(workout.averagePace, unit: unit), systemImage: "speedometer")
            }
            .font(.system(.subheadline, design: .default).monospacedDigit())
            .foregroundStyle(.secondary)
            .labelStyle(.titleOnly)
        }
        .padding(.vertical, 2)
    }
}
