//
//  WorkoutDetailView.swift
//  Splits
//
//  지도 → 요약 3개 → 랩 테이블.
//  랩·경로는 푸시 전환이 끝난 뒤 값 타입 스냅샷으로 한 번만 읽는다. 본문에서 SwiftData 관계와
//  경로 JSON을 반복해서 읽으면 첫 진입의 전환 애니메이션이 통째로 사라진다.
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
    /// 전환 뒤에 채워진다. nil이면 아직 읽기 전.
    @State private var snapshot: ShareableWorkout?
    @State private var mapReady = false

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }

    var body: some View {
        List {
            Section {
                mapArea
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let snapshot, snapshot.route.count >= 2 {
                            showFullMap = true
                        }
                    }
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
                if let snapshot, let goals = GoalSummary.compute(for: snapshot.laps) {
                    LabeledContent("목표 달성", value: "\(goals.met) / \(goals.total)")
                }
            }

            Section {
                if let snapshot {
                    let laps = snapshot.laps
                    let highlights = LapHighlight.compute(for: laps)
                    if laps.isEmpty {
                        Text("기록된 구간이 없어요.")
                            .foregroundStyle(.secondary)
                    } else {
                        LapTableHeader(numberTitle: LapTableLayout.isGrouped(laps) ? "세트" : "#")
                        ForEach(LapTableLayout.rows(for: laps)) { row in
                            LapRow(
                                lap: row.lap,
                                unit: unit,
                                highlight: highlights[row.lap.index],
                                number: row.number,
                                startsSet: row.startsSet
                            )
                        }
                    }
                } else {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("구간")
            } footer: {
                if let snapshot, !LapHighlight.compute(for: snapshot.laps).isEmpty {
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
        .confirmationDialog("이 기록을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                modelContext.delete(workout)
                dismiss()
            }
            Button("취소", role: .cancel) {}
        }
        .sheet(isPresented: $showFullMap) {
            if let snapshot {
                NavigationStack {
                    RouteMapView(route: snapshot.route, kinds: snapshot.stepKinds)
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
        .sheet(isPresented: $showShare) {
            ShareWorkoutView(workout: snapshot ?? workout.shareable)
        }
        .task {
            guard snapshot == nil else { return }
            // 푸시 전환(약 0.35초)이 끝난 뒤에 무거운 읽기를 한다.
            try? await Task.sleep(for: .milliseconds(380))
            let loaded = workout.shareable
            withAnimation(.easeOut(duration: 0.2)) {
                snapshot = loaded
            }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeOut(duration: 0.25)) {
                mapReady = true
            }
        }
    }

    @ViewBuilder
    private var mapArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardSecondary)
            if let snapshot {
                if snapshot.route.count >= 2 {
                    RouteSketch(route: snapshot.route, kinds: snapshot.stepKinds)
                        .padding(24)
                        .transition(.opacity)
                }
                if mapReady {
                    RouteMapView(route: snapshot.route, kinds: snapshot.stepKinds, interactive: false)
                        .transition(.opacity)
                }
            }
        }
    }
}
