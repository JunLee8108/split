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
    /// 행 스케치용 축소 경로 캐시. 행이 다시 그려져도 디코딩하지 않는다.
    @State private var previews: [PersistentIdentifier: RoutePreview] = [:]

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }

    private var months: [(month: Date, workouts: [Workout])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: workouts) { workout in
            calendar.date(from: calendar.dateComponents([.year, .month], from: workout.startedAt)) ?? workout.startedAt
        }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    /// 저장된 축소본이 있으면 그대로, 없으면(옛 기록) 백그라운드에서 만들어 모델에 채운다.
    private func loadPreview(for workout: Workout) async {
        let id = workout.persistentModelID
        guard previews[id] == nil else { return }
        if let stored = workout.routePreview {
            previews[id] = stored
            return
        }
        let data = workout.routeData
        let kinds = workout.stepKinds
        let preview = await Task.detached(priority: .utility) {
            let route = (try? JSONDecoder().decode([RoutePoint].self, from: data)) ?? []
            return RoutePreview.make(route: route, kinds: kinds)
        }.value
        previews[id] = preview
        workout.routePreview = preview
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
                            WorkoutCard(workout: workout, unit: unit, preview: previews[workout.persistentModelID])
                                .navigationRow(to: workout)
                                .cardRow()
                                .task(id: workout.persistentModelID) {
                                    await loadPreview(for: workout)
                                }
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
    var preview: RoutePreview? = nil

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.cardSecondary)
                if let preview {
                    RouteSketch(route: preview.points, kinds: preview.kinds)
                }
            }
            .frame(width: 60, height: 48)

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
