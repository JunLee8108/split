//
//  HistoryListView.swift
//  Splits
//
//  날짜별 섹션. 행마다 경로 스케치와 거리·시간·페이스.
//

import Foundation
import SwiftData
import SwiftUI

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }

    /// 최신 날짜부터. 같은 날 안에서는 이미 startedAt 역순이다.
    private var days: [(day: Date, workouts: [Workout])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: workouts) { calendar.startOfDay(for: $0.startedAt) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

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
                        ForEach(days, id: \.day) { entry in
                            Section {
                                ForEach(entry.workouts) { workout in
                                    NavigationLink(value: workout) {
                                        WorkoutRow(workout: workout, unit: unit)
                                    }
                                }
                                .onDelete { offsets in
                                    for index in offsets {
                                        modelContext.delete(entry.workouts[index])
                                    }
                                }
                            } header: {
                                Text(entry.day, format: .dateTime.year().month().day().weekday(.wide))
                            }
                        }
                    }
                }
            }
            .navigationTitle("기록")
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    let unit: DistanceUnit

    var body: some View {
        HStack(spacing: 12) {
            RouteSketch(route: workout.route, kinds: workout.stepKinds)
                .frame(width: 56, height: 44)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(workout.planName)
                        .font(.headline)
                    Spacer()
                    Text(workout.startedAt, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Text(Formatters.distance(workout.totalDistance, unit: unit))
                    Text(Formatters.clock(workout.movingTime))
                    Text(Formatters.pace(workout.averagePace, unit: unit))
                }
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
