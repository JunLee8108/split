//
//  HistoryListView.swift
//  Splits
//
//  월별로 기록 카드가 이어진다.
//

import Foundation
import SwiftData
import SwiftUI

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue

    @State private var sharing: Workout?

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }

    private var months: [(month: Date, workouts: [Workout])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: workouts) { workout in
            calendar.date(from: calendar.dateComponents([.year, .month], from: workout.startedAt)) ?? workout.startedAt
        }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            List {
                if workouts.isEmpty {
                    EmptyCard(
                        systemImage: "clock",
                        title: "아직 기록이 없어요",
                        message: "플랜을 골라 첫 세션을 뛰면 여기에 쌓입니다."
                    )
                    .cardRow(top: 16)
                } else {
                    ForEach(months, id: \.month) { entry in
                        SectionLabel(entry.month.formatted(.dateTime.year().month(.wide)))
                            .cardRow(top: entry.month == months.first?.month ? 8 : 0, bottom: 4)
                        ForEach(entry.workouts) { workout in
                            WorkoutCard(workout: workout, unit: unit)
                                .navigationRow(to: workout)
                                .cardRow()
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(workout)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    sharing = workout
                                } label: {
                                    Label("공유", systemImage: "square.and.arrow.up")
                                }
                                Button(role: .destructive) {
                                    modelContext.delete(workout)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
            .sheet(item: $sharing) { workout in
                ShareWorkoutView(workout: workout.shareable)
            }
        }
    }
}

struct WorkoutCard: View {
    let workout: Workout
    let unit: DistanceUnit

    var body: some View {
        HStack(spacing: 14) {
            RouteSketch(route: workout.route, kinds: workout.stepKinds)
                .frame(width: 60, height: 48)
                .background(Color.cardSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(workout.planName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(workout.startedAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Text(Formatters.distance(workout.totalDistance, unit: unit))
                        .foregroundStyle(.primary)
                    Text(Formatters.clock(workout.movingTime))
                    Text(Formatters.pace(workout.averagePace, unit: unit))
                }
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .card()
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
    }
}
