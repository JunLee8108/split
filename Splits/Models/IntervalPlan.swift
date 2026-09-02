//
//  IntervalPlan.swift
//  Splits
//

import Foundation
import SwiftData

@Model
final class IntervalPlan {
    var name: String
    var createdAt: Date
    var repeatCount: Int
    var warmupSeconds: TimeInterval?
    var cooldownSeconds: TimeInterval?
    var isPreset: Bool

    @Relationship(deleteRule: .cascade, inverse: \Segment.plan)
    var segments: [Segment]

    init(
        name: String,
        repeatCount: Int = 1,
        warmupSeconds: TimeInterval? = nil,
        cooldownSeconds: TimeInterval? = nil,
        isPreset: Bool = false,
        createdAt: Date = .now
    ) {
        self.name = name
        self.repeatCount = max(repeatCount, 1)
        self.warmupSeconds = warmupSeconds
        self.cooldownSeconds = cooldownSeconds
        self.isPreset = isPreset
        self.createdAt = createdAt
        self.segments = []
    }

    var orderedSegments: [Segment] {
        segments.sorted { $0.order < $1.order }
    }

    var blueprint: PlanBlueprint {
        PlanBlueprint(
            name: name,
            segments: orderedSegments.map { SegmentSpec(kind: $0.kind, target: $0.target, goalValue: $0.goalValue) },
            repeatCount: repeatCount,
            warmupSeconds: warmupSeconds,
            cooldownSeconds: cooldownSeconds
        )
    }

    /// 구간 배열을 통째로 교체한다. order는 배열 순서로 다시 매긴다.
    func replaceSegments(with specs: [SegmentSpec]) {
        segments = specs.enumerated().map { index, spec in
            Segment(kind: spec.kind, target: spec.target, order: index, goalValue: spec.goalValue)
        }
    }

    /// 같은 내용의 새 플랜을 만들어 컨텍스트에 넣는다.
    @discardableResult
    func duplicate(into context: ModelContext) -> IntervalPlan {
        let copy = IntervalPlan(
            name: "\(name) 복사본",
            repeatCount: repeatCount,
            warmupSeconds: warmupSeconds,
            cooldownSeconds: cooldownSeconds
        )
        context.insert(copy)
        copy.replaceSegments(with: blueprint.segments)
        return copy
    }
}

@Model
final class Segment {
    var kindRaw: String
    var targetKindRaw: String
    var targetValue: Double
    var order: Int
    /// 거리 구간이면 목표 시간(초), 시간 구간이면 목표 거리(미터).
    var goalValue: Double?
    var plan: IntervalPlan?

    init(kind: StepKind, target: SegmentTarget, order: Int, goalValue: Double? = nil) {
        self.kindRaw = kind.rawValue
        self.targetKindRaw = target.storageKind
        self.targetValue = target.value
        self.order = order
        self.goalValue = goalValue
    }

    var kind: StepKind {
        get { StepKind(rawValue: kindRaw) ?? .run }
        set { kindRaw = newValue.rawValue }
    }

    var target: SegmentTarget {
        get { SegmentTarget(storageKind: targetKindRaw, value: targetValue) }
        set {
            targetKindRaw = newValue.storageKind
            targetValue = newValue.value
        }
    }
}
