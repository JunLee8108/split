//
//  ShareCardView.swift
//  Splits
//
//  공유 이미지 한 장. 세션 화면과 같은 어두운 바탕, 둥근 큰 숫자, 주황·청록.
//  포인트 단위로 그리고 ImageRenderer가 3배로 키운다.
//

import SwiftUI

enum ShareCardFormat: String, CaseIterable, Identifiable {
    case feed
    case story

    var id: String { rawValue }

    var label: String {
        switch self {
        case .feed: "피드 4:5"
        case .story: "스토리 9:16"
        }
    }

    /// 포인트 크기. ×3 하면 1080×1350, 1080×1920.
    var size: CGSize {
        switch self {
        case .feed: CGSize(width: 360, height: 450)
        case .story: CGSize(width: 360, height: 640)
        }
    }
}

struct ShareCardView: View {
    let workout: ShareableWorkout
    let unit: DistanceUnit
    let format: ShareCardFormat

    private var runs: [LapRecord] { workout.runLaps }

    var body: some View {
        ZStack(alignment: .topLeading) {
            SessionBackground.base
            Color.run.opacity(0.10)
            Circle()
                .fill(Color.run.opacity(0.10))
                .frame(width: 300, height: 300)
                .offset(x: 200, y: -140)

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, format == .story ? 28 : 18)

                Text(workout.planName)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, format == .story ? 22 : 14)

                routeArea
                    .frame(height: format == .story ? 190 : 130)
                    .padding(.bottom, format == .story ? 26 : 16)

                stats
                    .padding(.bottom, format == .story ? 30 : 18)

                if !runs.isEmpty {
                    lapBars
                }

                Spacer(minLength: 0)

                footer
            }
            .padding(24)
        }
        .frame(width: format.size.width, height: format.size.height)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 5) {
                Text("SPLITS")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.85))
                Circle().fill(Color.rest).frame(width: 5, height: 5)
            }
            Spacer()
            Text(workout.startedAt.formatted(.dateTime.year().month().day().hour().minute()))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var routeArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.06))
            if workout.route.count >= 2 {
                RouteSketch(route: workout.route, kinds: workout.stepKinds)
                    .padding(14)
            } else {
                Image(systemName: "figure.run")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.run)
            }
        }
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: 0) {
            stat(Formatters.distance(workout.totalDistance, unit: unit), "거리")
            stat(Formatters.clock(workout.movingTime), "시간")
            stat(Formatters.pace(workout.averagePace, unit: unit), "평균 페이스")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 달리기 구간 시간 막대. 목표가 같으면 목표선을 긋는다.
    private var lapBars: some View {
        let maxDuration = max(runs.map(\.duration).max() ?? 1, 1)
        let goal = runs.first?.goalValue
        let sameGoal = goal != nil && runs.allSatisfy { $0.goalValue == goal && $0.target.isDistance }
        let barHeight: CGFloat = format == .story ? 84 : 64

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("달리기 \(runs.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                if let fastest = runs.compactMap(\.pace).min() {
                    Text("최고 \(Formatters.pace(fastest, unit: unit))")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.6))
                }
                if let goals = GoalSummary.compute(for: workout.laps) {
                    Text("목표 \(goals.met)/\(goals.total)")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.rest)
                }
            }

            ZStack(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: runs.count > 16 ? 2 : 4) {
                    ForEach(runs, id: \.index) { lap in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(lap.goalMet == false ? Color.run.opacity(0.45) : Color.run)
                            .frame(height: max(barHeight * lap.duration / maxDuration, 4))
                    }
                }
                if sameGoal, let goal {
                    Rectangle()
                        .fill(Color.rest)
                        .frame(height: 1.5)
                        .offset(y: -barHeight * goal / maxDuration)
                }
            }
            .frame(height: barHeight, alignment: .bottom)
        }
    }

    private var footer: some View {
        HStack {
            if let goal = runs.first?.goalValue, runs.first?.target.isDistance == true {
                Text("목표 \(Formatters.clock(goal)) · \(Formatters.pace(GoalMath.pace(target: runs.first!.target, goalValue: goal), unit: unit))/\(unit == .metric ? "km" : "mi")")
            } else {
                Text("인터벌 러닝")
            }
            Spacer()
        }
        .font(.system(size: 11, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(.white.opacity(0.5))
        .padding(.top, 14)
    }
}

#Preview("feed") {
    ShareCardView(
        workout: ShareableWorkout(
            planName: "400m × 12",
            startedAt: .now,
            totalDistance: 7000,
            movingTime: 2712,
            laps: (0..<12).map { i in
                LapRecord(index: i * 2 + 1, kind: .run, target: .distance(400), distance: 400, duration: 95 + Double(i) * 2, goalValue: 100, ordinal: i + 1, setIndex: i + 1)
            },
            route: []
        ),
        unit: .metric,
        format: .feed
    )
}
