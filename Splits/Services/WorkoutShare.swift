//
//  WorkoutShare.swift
//  Splits
//
//  공유용 스냅샷과 텍스트 요약. 모델(Workout)과 세션 요약(WorkoutSummary) 둘 다에서 만든다.
//

import Foundation

nonisolated struct ShareableWorkout: Hashable, Sendable {
    var planName: String
    var startedAt: Date
    var totalDistance: Double
    var movingTime: TimeInterval
    var laps: [LapRecord]
    var route: [RoutePoint]

    var averagePace: TimeInterval? { PaceMath.pace(distance: totalDistance, duration: movingTime) }
    var runLaps: [LapRecord] { laps.filter { $0.kind == .run } }

    var stepKinds: [Int: StepKind] {
        Dictionary(laps.map { ($0.index, $0.kind) }, uniquingKeysWith: { first, _ in first })
    }

    init(summary: WorkoutSummary) {
        planName = summary.planName
        startedAt = summary.startedAt
        totalDistance = summary.totalDistance
        movingTime = summary.movingTime
        laps = summary.laps
        route = summary.route
    }

    init(planName: String, startedAt: Date, totalDistance: Double, movingTime: TimeInterval, laps: [LapRecord], route: [RoutePoint]) {
        self.planName = planName
        self.startedAt = startedAt
        self.totalDistance = totalDistance
        self.movingTime = movingTime
        self.laps = laps
        self.route = route
    }
}

extension Workout {
    var shareable: ShareableWorkout {
        ShareableWorkout(
            planName: planName,
            startedAt: startedAt,
            totalDistance: totalDistance,
            movingTime: movingTime,
            laps: lapRecords,
            route: route
        )
    }
}

nonisolated enum ShareText {
    /// 메시지에 붙이기 좋은 짧은 요약.
    ///
    ///     400m × 12 · 9월 2일 (화)
    ///     7.00 km · 45:12 · 5'02"/km
    ///     달리기 12: 1:35 · 1:43 · 1:53 …
    ///     목표 달성 9 / 12
    ///     Splits
    static func summary(_ workout: ShareableWorkout, unit: DistanceUnit = .metric) -> String {
        var lines: [String] = []
        let date = workout.startedAt.formatted(.dateTime.month().day().weekday(.abbreviated))
        lines.append("\(workout.planName) · \(date)")

        let paceUnit = unit == .metric ? "km" : "mi"
        lines.append("\(Formatters.distance(workout.totalDistance, unit: unit)) · \(Formatters.clock(workout.movingTime)) · \(Formatters.pace(workout.averagePace, unit: unit))/\(paceUnit)")

        let runs = workout.runLaps
        if !runs.isEmpty {
            let times = runs.map { Formatters.clock($0.duration) }.joined(separator: " · ")
            lines.append("달리기 \(runs.count): \(times)")
        }

        if let goals = GoalSummary.compute(for: workout.laps) {
            lines.append("목표 달성 \(goals.met) / \(goals.total)")
        }

        lines.append("Splits")
        return lines.joined(separator: "\n")
    }
}
