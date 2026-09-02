//
//  SegmentTracker.swift
//  Splits
//
//  현재 구간 하나의 진행 상태. 거리와 시간을 둘 다 세고, 목표 종류에 따라 완료를 판정한다.
//

import Foundation

nonisolated struct SegmentTracker: Hashable, Sendable {
    let step: WorkoutStep
    private(set) var distance: Double
    private(set) var elapsed: TimeInterval

    /// 직전 구간에서 넘친 거리·시간을 이어받아 시작한다.
    init(step: WorkoutStep, carriedDistance: Double = 0, carriedTime: TimeInterval = 0) {
        self.step = step
        self.distance = max(carriedDistance, 0)
        self.elapsed = max(carriedTime, 0)
    }

    mutating func add(distance meters: Double) {
        guard meters > 0 else { return }
        distance += meters
    }

    mutating func add(time seconds: TimeInterval) {
        guard seconds > 0 else { return }
        elapsed += seconds
    }

    /// 목표까지 남은 양. 거리 목표면 미터, 시간 목표면 초. 0 아래로 내려가지 않는다.
    var remaining: Double {
        switch step.target {
        case .distance(let target): max(target - distance, 0)
        case .duration(let target): max(target - elapsed, 0)
        }
    }

    /// 0...1
    var progress: Double {
        let target = step.target.value
        guard target > 0 else { return 1 }
        let done = step.target.isDistance ? distance : elapsed
        return min(max(done / target, 0), 1)
    }

    var isComplete: Bool {
        switch step.target {
        case .distance(let target): distance >= target
        case .duration(let target): elapsed >= target
        }
    }

    /// 목표를 넘긴 만큼. 다음 구간으로 이어 넘긴다.
    var overflow: (distance: Double, time: TimeInterval) {
        switch step.target {
        case .distance(let target): (max(distance - target, 0), 0)
        case .duration(let target): (0, max(elapsed - target, 0))
        }
    }

    /// 지금까지의 결과를 랩으로 확정한다.
    func lapRecord() -> LapRecord {
        LapRecord(
            index: step.index,
            kind: step.kind,
            target: step.target,
            distance: distance,
            duration: elapsed,
            goalValue: step.goalValue,
            ordinal: step.ordinal
        )
    }
}

nonisolated struct LapRecord: Hashable, Sendable {
    var index: Int
    var kind: StepKind
    var target: SegmentTarget
    var distance: Double
    var duration: TimeInterval
    /// 거리 구간이면 목표 시간(초), 시간 구간이면 목표 거리(미터).
    var goalValue: Double? = nil
    /// 같은 종류 중 몇 번째인지. 저장된 기록에서는 0(모름).
    var ordinal: Int = 0

    var pace: TimeInterval? { PaceMath.pace(distance: distance, duration: duration) }

    var goalPace: TimeInterval? { GoalMath.pace(target: target, goalValue: goalValue) }

    /// 목표 대비 차이. 시간 목표는 초(음수 = 빠름), 거리 목표는 미터(양수 = 더 감).
    var goalDelta: Double? {
        guard let goalValue, goalValue > 0 else { return nil }
        switch target {
        case .distance: return duration - goalValue
        case .duration: return distance - goalValue
        }
    }

    var goalMet: Bool? {
        guard let delta = goalDelta else { return nil }
        return target.isDistance ? delta <= 0 : delta >= 0
    }
}
