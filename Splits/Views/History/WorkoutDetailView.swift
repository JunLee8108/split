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
    @State private var showShare = false
    /// 푸시 전환이 끝난 뒤에 지도를 넣는다. 첫 지도 생성이 무거워 전환 프레임을 잡아먹는다.
    @State private var mapReady = false

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }
    private var laps: [LapRecord] { workout.lapRecords }
    private var highlights: [Int: LapHighlight] { LapHighlight.compute(for: laps) }

    var body: some View {
        List {
            Section {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cardSecondary)
                    if workout.route.count >= 2 {
                        RouteSketch(route: workout.route, kinds: workout.stepKinds)
                            .padding(24)
                    }
                    if mapReady {
                        RouteMapView(route: workout.route, kinds: workout.stepKinds, interactive: false)
                            .transition(.opacity)
                    }
                }
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
                SummaryStatsRow(
                    distance: workout.totalDistance,
                    movingTime: workout.movingTime,
                    averagePace: workout.averagePace,
                    unit: unit
                )
                if let goals = GoalSummary.compute(for: laps) {
                    LabeledContent("목표 달성", value: "\(goals.met) / \(goals.total)")
                }
            }

            Section {
                if laps.isEmpty {
                    Text("기록된 구간이 없어요.")
                        .foregroundStyle(.secondary)
                } else {
                    LapTableHeader(numberTitle: LapTableLayout.isGrouped(laps) ? "세트" : "#")
                }
                ForEach(LapTableLayout.rows(for: laps)) { row in
                    LapRow(
                        lap: row.lap,
                        unit: unit,
                        highlight: highlights[row.lap.index],
                        number: row.number,
                        startsSet: row.startsSet
                    )
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
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showShare = true
                } label: {
                    Label("공유", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ShareWorkoutView(workout: workout.shareable)
        }
        .task {
            guard !mapReady else { return }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeOut(duration: 0.25)) {
                mapReady = true
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
