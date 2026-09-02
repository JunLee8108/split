//
//  Workout.swift
//  Splits
//

import Foundation
import SwiftData

/// 경로의 한 점. 구조체 배열을 JSON으로 직렬화해 Workout.routeData에 저장한다.
nonisolated struct RoutePoint: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    /// 이 점이 속한 스텝의 index.
    var stepIndex: Int
}

@Model
final class Workout {
    var startedAt: Date
    var endedAt: Date
    /// 미터.
    var totalDistance: Double
    /// 초. 일시정지 시간은 제외.
    var movingTime: TimeInterval
    /// 초/km. 거리가 없으면 nil.
    var averagePace: TimeInterval?
    /// 플랜 이름 스냅샷. 플랜을 나중에 고쳐도 기록은 그대로다.
    var planName: String
    var routeData: Data

    @Relationship(deleteRule: .cascade, inverse: \Lap.workout)
    var laps: [Lap]

    init(
        startedAt: Date,
        endedAt: Date,
        totalDistance: Double,
        movingTime: TimeInterval,
        averagePace: TimeInterval?,
        planName: String,
        routeData: Data = Data()
    ) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalDistance = totalDistance
        self.movingTime = movingTime
        self.averagePace = averagePace
        self.planName = planName
        self.routeData = routeData
        self.laps = []
    }

    var route: [RoutePoint] {
        get { (try? JSONDecoder().decode([RoutePoint].self, from: routeData)) ?? [] }
        set { routeData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var orderedLaps: [Lap] {
        laps.sorted { $0.index < $1.index }
    }

    var lapRecords: [LapRecord] {
        orderedLaps.map(\.record)
    }

    /// 스텝 index → 구간 종류. 경로 색칠에 쓴다.
    var stepKinds: [Int: StepKind] {
        Dictionary(laps.map { ($0.index, $0.kind) }, uniquingKeysWith: { first, _ in first })
    }

    /// 완료된 세션 요약을 저장용 모델로 바꿔 컨텍스트에 넣는다.
    @discardableResult
    static func save(_ summary: WorkoutSummary, into context: ModelContext) -> Workout {
        let workout = Workout(
            startedAt: summary.startedAt,
            endedAt: summary.endedAt,
            totalDistance: summary.totalDistance,
            movingTime: summary.movingTime,
            averagePace: summary.averagePace,
            planName: summary.planName
        )
        workout.route = summary.route
        context.insert(workout)
        workout.laps = summary.laps.map { Lap(record: $0) }
        return workout
    }
}

@Model
final class Lap {
    var index: Int
    var kindRaw: String
    var targetKindRaw: String
    var targetValue: Double
    /// 미터.
    var distance: Double
    /// 초.
    var duration: TimeInterval
    /// 거리 구간이면 목표 시간(초), 시간 구간이면 목표 거리(미터).
    var goalValue: Double?
    var workout: Workout?

    init(index: Int, kind: StepKind, target: SegmentTarget, distance: Double, duration: TimeInterval, goalValue: Double? = nil) {
        self.index = index
        self.kindRaw = kind.rawValue
        self.targetKindRaw = target.storageKind
        self.targetValue = target.value
        self.distance = distance
        self.duration = duration
        self.goalValue = goalValue
    }

    convenience init(record: LapRecord) {
        self.init(
            index: record.index,
            kind: record.kind,
            target: record.target,
            distance: record.distance,
            duration: record.duration,
            goalValue: record.goalValue
        )
    }

    var kind: StepKind { StepKind(rawValue: kindRaw) ?? .run }
    var target: SegmentTarget { SegmentTarget(storageKind: targetKindRaw, value: targetValue) }

    /// 초/km. 거리가 너무 짧으면 nil.
    var pace: TimeInterval? { PaceMath.pace(distance: distance, duration: duration) }

    var record: LapRecord {
        LapRecord(index: index, kind: kind, target: target, distance: distance, duration: duration, goalValue: goalValue)
    }
}
