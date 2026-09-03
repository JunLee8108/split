//
//  PlanBlueprint.swift
//  Splits
//
//  SwiftData 모델과 무관한 순수 값 타입. 엔진과 테스트는 이것만 본다.
//

import Foundation

nonisolated struct SegmentSpec: Hashable, Sendable {
    var kind: StepKind
    var target: SegmentTarget
    /// 거리 구간이면 목표 시간(초), 시간 구간이면 목표 거리(미터). 없으면 nil.
    var goalValue: Double? = nil

    static func run(meters: Double) -> SegmentSpec { .init(kind: .run, target: .distance(meters)) }
    static func run(seconds: TimeInterval) -> SegmentSpec { .init(kind: .run, target: .duration(seconds)) }
    static func rest(seconds: TimeInterval) -> SegmentSpec { .init(kind: .rest, target: .duration(seconds)) }
    static func rest(meters: Double) -> SegmentSpec { .init(kind: .rest, target: .distance(meters)) }
}

/// 세션이 실제로 실행할 한 구간. 플랜을 펼친 결과다.
nonisolated struct WorkoutStep: Hashable, Sendable {
    var kind: StepKind
    var target: SegmentTarget
    /// 전체 스텝 목록에서의 위치 (0부터).
    var index: Int
    /// 같은 종류 중 몇 번째인지 (1부터). "달리기 3 / 8"의 3.
    var ordinal: Int
    /// 같은 종류의 총 개수. "달리기 3 / 8"의 8.
    var ordinalTotal: Int
    /// 거리 구간이면 목표 시간(초), 시간 구간이면 목표 거리(미터).
    var goalValue: Double? = nil
    /// 몇 번째 세트인지 (1부터). 세트 = 플랜의 구간 묶음을 한 번 도는 것. 워밍업·쿨다운은 nil.
    var setIndex: Int? = nil

    /// 목표 페이스(초/km).
    var goalPace: TimeInterval? { GoalMath.pace(target: target, goalValue: goalValue) }
}

nonisolated struct PlanBlueprint: Hashable, Sendable {
    var name: String
    var segments: [SegmentSpec]
    var repeatCount: Int
    var warmupSeconds: TimeInterval?
    var cooldownSeconds: TimeInterval?

    init(
        name: String,
        segments: [SegmentSpec],
        repeatCount: Int = 1,
        warmupSeconds: TimeInterval? = nil,
        cooldownSeconds: TimeInterval? = nil
    ) {
        self.name = name
        self.segments = segments
        self.repeatCount = max(repeatCount, 1)
        self.warmupSeconds = warmupSeconds
        self.cooldownSeconds = cooldownSeconds
    }

    /// 플랜을 실행 순서대로 펼친다.
    /// 마지막 반복의 끝이 회복 구간이면 하나 제거한다. 마지막 달리기 뒤에 쉬는 건 세션 종료다.
    func steps() -> [WorkoutStep] {
        var raw: [(kind: StepKind, target: SegmentTarget, goal: Double?, set: Int?)] = []

        if let warmupSeconds, warmupSeconds > 0 {
            raw.append((.warmup, .duration(warmupSeconds), nil, nil))
        }

        for repetition in 0..<repeatCount {
            for segment in segments {
                raw.append((segment.kind, segment.target, segment.goalValue, repetition + 1))
            }
        }

        if raw.last?.kind == .rest {
            raw.removeLast()
        }

        if let cooldownSeconds, cooldownSeconds > 0 {
            raw.append((.cooldown, .duration(cooldownSeconds), nil, nil))
        }

        var totals: [StepKind: Int] = [:]
        for entry in raw {
            totals[entry.kind, default: 0] += 1
        }

        var counters: [StepKind: Int] = [:]
        return raw.enumerated().map { index, entry in
            counters[entry.kind, default: 0] += 1
            return WorkoutStep(
                kind: entry.kind,
                target: entry.target,
                index: index,
                ordinal: counters[entry.kind] ?? 1,
                ordinalTotal: totals[entry.kind] ?? 1,
                goalValue: entry.goal,
                setIndex: entry.set
            )
        }
    }

    /// 거리 목표 구간의 합(미터). 시간 목표 구간은 포함하지 않는다.
    var plannedDistance: Double {
        steps().compactMap(\.target.meters).reduce(0, +)
    }

    /// 시간 기준 구간의 합(초). 거리 기준 구간은 포함하지 않는다.
    var plannedDuration: TimeInterval {
        steps().compactMap(\.target.seconds).reduce(0, +)
    }

    /// 예상 소요 시간. 워밍업 + 각 구간(시간 기준이면 그 시간, 거리 기준이면 목표 시간) + 쿨다운.
    /// 목표가 없는 거리 구간은 더할 수 없어 `unknownSteps`로 센다.
    var estimatedDuration: (seconds: TimeInterval, unknownSteps: Int) {
        var total: TimeInterval = 0
        var unknown = 0
        for step in steps() {
            switch step.target {
            case .duration(let seconds):
                total += seconds
            case .distance:
                if let goal = step.goalValue, goal > 0 {
                    total += goal
                } else {
                    unknown += 1
                }
            }
        }
        return (total, unknown)
    }
}
