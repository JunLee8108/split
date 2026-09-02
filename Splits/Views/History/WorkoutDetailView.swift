//
//  WorkoutDetailView.swift
//  Splits
//
//  지도 → 요약 3개 → 랩 테이블.
//

import SwiftData
import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue
    @State private var showFullMap = false
    @State private var confirmDelete = false

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }
    private var laps: [LapRecord] { workout.lapRecords }
    private var highlights: [Int: LapHighlight] { LapHighlight.compute(for: laps) }

    var body: some View {
        List {
            Section {
                RouteMapView(route: workout.route, kinds: workout.stepKinds, interactive: false)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                    .onTapGesture { showFullMap = !workout.route.isEmpty }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .accessibilityLabel("경로 지도")
                    .accessibilityAddTraits(.isButton)
            }

            Section {
                HStack(alignment: .top, spacing: 0) {
                    DetailStat(value: Formatters.distanceValue(workout.totalDistance, unit: unit).value,
                               label: Formatters.distanceValue(workout.totalDistance, unit: unit).unit)
                    DetailStat(value: Formatters.clock(workout.movingTime), label: "시간")
                    DetailStat(value: Formatters.pace(workout.averagePace, unit: unit), label: "평균 페이스")
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
                if let goals = GoalSummary.compute(for: laps) {
                    LabeledContent("목표 달성", value: "\(goals.met) / \(goals.total)")
                }
            }

            Section {
                if laps.isEmpty {
                    Text("기록된 구간이 없어요.")
                        .foregroundStyle(.secondary)
                }
                ForEach(laps, id: \.index) { lap in
                    LapRow(lap: lap, unit: unit, highlight: highlights[lap.index])
                }
            } header: {
                Text("구간")
            } footer: {
                if !highlights.isEmpty {
                    Text("달리기 구간 중 가장 빠른 것과 느린 것을 화살표로 표시합니다.")
                }
            }
        }
        .navigationTitle(workout.planName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(workout.planName).font(.headline)
                    Text(workout.startedAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("이 기록을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                modelContext.delete(workout)
                dismiss()
            }
            Button("취소", role: .cancel) {}
        }
        .sheet(isPresented: $showFullMap) {
            NavigationStack {
                RouteMapView(route: workout.route, kinds: workout.stepKinds)
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle("경로")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("닫기") { showFullMap = false }
                        }
                    }
            }
        }
    }
}

private struct DetailStat: View {
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
