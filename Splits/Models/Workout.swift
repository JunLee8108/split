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

/// 목록 스케치용 축소 경로. 전체 경로(수천 점) 대신 이것만 읽는다.
nonisolated struct RoutePreview: Codable, Hashable, Sendable {
    var points: [RoutePoint]
    var kinds: [Int: StepKind]

    static let maxPoints = 160

    /// 균등하게 솎되 구간이 바뀌는 점과 마지막 점은 남긴다. 색 경계가 유지된다.
    static func make(route: [RoutePoint], kinds: [Int: StepKind], maxPoints: Int = RoutePreview.maxPoints) -> RoutePreview {
        guard route.count > maxPoints else { return RoutePreview(points: route, kinds: kinds) }
        let stride = Int((Double(route.count) / Double(maxPoints)).rounded(.up))
        var kept: [RoutePoint] = []
        kept.reserveCapacity(maxPoints + 16)
        var previousStep: Int?
        for (offset, point) in route.enumerated() {
            let boundary = previousStep != nil && point.stepIndex != previousStep
            if offset % stride == 0 || boundary || offset == route.count - 1 {
                kept.append(point)
            }
            previousStep = point.stepIndex
        }
        return RoutePreview(points: kept, kinds: kinds)
    }
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
    /// RoutePreview JSON. 저장 시 만들고, 옛 기록은 목록이 처음 볼 때 채운다.
    var routePreviewData: Data?

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

    var routePreview: RoutePreview? {
        get {
            guard let routePreviewData else { return nil }
            return try? JSONDecoder().decode(RoutePreview.self, from: routePreviewData)
        }
        set { routePreviewData = try? JSONEncoder().encode(newValue) }
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
        let kinds = Dictionary(summary.laps.map { ($0.index, $0.kind) }, uniquingKeysWith: { first, _ in first })
        workout.routePreview = RoutePreview.make(route: summary.route, kinds: kinds)
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
    /// 몇 번째 세트인지 (1부터). 워밍업·쿨다운은 nil.
    var setIndex: Int?
    var workout: Workout?

    init(
        index: Int,
        kind: StepKind,
        target: SegmentTarget,
        distance: Double,
        duration: TimeInterval,
        goalValue: Double? = nil,
        setIndex: Int? = nil
    ) {
        self.index = index
        self.kindRaw = kind.rawValue
        self.targetKindRaw = target.storageKind
        self.targetValue = target.value
        self.distance = distance
        self.duration = duration
        self.goalValue = goalValue
        self.setIndex = setIndex
    }

    convenience init(record: LapRecord) {
        self.init(
            index: record.index,
            kind: record.kind,
            target: record.target,
            distance: record.distance,
            duration: record.duration,
            goalValue: record.goalValue,
            setIndex: record.setIndex
        )
    }

    var kind: StepKind { StepKind(rawValue: kindRaw) ?? .run }
    var target: SegmentTarget { SegmentTarget(storageKind: targetKindRaw, value: targetValue) }

    /// 초/km. 거리가 너무 짧으면 nil.
    var pace: TimeInterval? { PaceMath.pace(distance: distance, duration: duration) }

    var record: LapRecord {
        LapRecord(
            index: index,
            kind: kind,
            target: target,
            distance: distance,
            duration: duration,
            goalValue: goalValue,
            setIndex: setIndex
        )
    }
}
