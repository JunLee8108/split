//
//  HistoryListView.swift
//  Splits
//
//  이번 주 요약 카드로 시작하고, 월별로 기록 카드가 이어진다.
//

import Charts
import Foundation
import SwiftData
import SwiftUI

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue

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
                ScreenHeader(eyebrow: "이번 주") {
                    EmptyView()
                }
                .cardRow(top: 8, bottom: Metrics.headerGap)

                WeekSummaryCard(workouts: workouts, unit: unit)
                    .cardRow()

                if workouts.isEmpty {
                    EmptyCard(
                        systemImage: "clock",
                        title: "아직 기록이 없어요",
                        message: "플랜을 골라 첫 세션을 뛰면 여기에 한 주가 쌓입니다."
                    )
                    .cardRow()
                } else {
                    ForEach(months, id: \.month) { entry in
                        SectionLabel(entry.month.formatted(.dateTime.year().month(.wide)))
                            .cardRow(bottom: 4)
                        ForEach(entry.workouts) { workout in
                            NavigationLink(value: workout) {
                                WorkoutCard(workout: workout, unit: unit)
                            }
                            .buttonStyle(.plain)
                            .cardRow()
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(workout)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                            .contextMenu {
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
        }
    }
}

/// 청록 톤 카드. 이번 주 거리·세션·시간과 최근 7일 막대.
struct WeekSummaryCard: View {
    let workouts: [Workout]
    let unit: DistanceUnit

    private struct DayEntry: Identifiable {
        let day: Date
        let meters: Double
        var id: Date { day }
    }

    private var calendar: Calendar { Calendar.current }

    private var thisWeek: [Workout] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return workouts.filter { interval.contains($0.startedAt) }
    }

    private var lastSevenDays: [DayEntry] {
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let meters = workouts
                .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.totalDistance }
            return DayEntry(day: day, meters: meters)
        }
    }

    private var weekDistance: Double { thisWeek.reduce(0) { $0 + $1.totalDistance } }
    private var weekTime: TimeInterval { thisWeek.reduce(0) { $0 + $1.movingTime } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 8) {
                let distance = Formatters.distanceValue(weekDistance, unit: unit)
                StatTile(value: distance.value, label: distance.unit)
                StatTile(value: "\(thisWeek.count)", label: "세션")
                StatTile(value: Formatters.clock(weekTime), label: "시간")
            }

            Chart(lastSevenDays) { entry in
                BarMark(
                    x: .value("날짜", entry.day, unit: .day),
                    y: .value("거리", chartValue(entry.meters))
                )
                .foregroundStyle(Color.rest)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...max(chartMax, 1))
            .frame(height: 72)
            .accessibilityLabel("최근 7일 일별 거리")
        }
        .card(background: Color.rest.opacity(0.14))
    }

    private func chartValue(_ meters: Double) -> Double {
        unit == .metric ? meters / 1000 : meters / Formatters.metersPerMile
    }

    private var chartMax: Double {
        lastSevenDays.map { chartValue($0.meters) }.max() ?? 0
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
