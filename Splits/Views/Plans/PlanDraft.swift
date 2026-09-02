//
//  PlanDraft.swift
//  Splits
//
//  편집기가 다루는 값 타입 초안. 저장을 누를 때만 SwiftData 모델에 쓴다.
//

import Foundation
import SwiftData

struct SegmentDraft: Identifiable, Hashable {
    let id: UUID
    var kind: StepKind
    var target: SegmentTarget

    init(id: UUID = UUID(), kind: StepKind, target: SegmentTarget) {
        self.id = id
        self.kind = kind
        self.target = target
    }

    init(spec: SegmentSpec) {
        self.init(kind: spec.kind, target: spec.target)
    }

    var spec: SegmentSpec { SegmentSpec(kind: kind, target: target) }
}

struct PlanDraft: Hashable {
    var name: String
    var segments: [SegmentDraft]
    var repeatCount: Int
    var hasWarmup: Bool
    var warmupSeconds: TimeInterval
    var hasCooldown: Bool
    var cooldownSeconds: TimeInterval

    static let defaultWarmup: TimeInterval = 300
    static let defaultCooldown: TimeInterval = 300

    /// 새 플랜의 출발점.
    static func new() -> PlanDraft {
        PlanDraft(
            name: "",
            segments: [
                SegmentDraft(spec: .run(meters: 400)),
                SegmentDraft(spec: .rest(seconds: 90)),
            ],
            repeatCount: 4,
            hasWarmup: false,
            warmupSeconds: defaultWarmup,
            hasCooldown: false,
            cooldownSeconds: defaultCooldown
        )
    }

    init(
        name: String,
        segments: [SegmentDraft],
        repeatCount: Int,
        hasWarmup: Bool,
        warmupSeconds: TimeInterval,
        hasCooldown: Bool,
        cooldownSeconds: TimeInterval
    ) {
        self.name = name
        self.segments = segments
        self.repeatCount = repeatCount
        self.hasWarmup = hasWarmup
        self.warmupSeconds = warmupSeconds
        self.hasCooldown = hasCooldown
        self.cooldownSeconds = cooldownSeconds
    }

    init(plan: IntervalPlan) {
        let blueprint = plan.blueprint
        self.init(
            name: blueprint.name,
            segments: blueprint.segments.map { SegmentDraft(spec: $0) },
            repeatCount: blueprint.repeatCount,
            hasWarmup: blueprint.warmupSeconds != nil,
            warmupSeconds: blueprint.warmupSeconds ?? Self.defaultWarmup,
            hasCooldown: blueprint.cooldownSeconds != nil,
            cooldownSeconds: blueprint.cooldownSeconds ?? Self.defaultCooldown
        )
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isValid: Bool { !trimmedName.isEmpty && !segments.isEmpty }

    var blueprint: PlanBlueprint {
        PlanBlueprint(
            name: trimmedName.isEmpty ? "새 플랜" : trimmedName,
            segments: segments.map(\.spec),
            repeatCount: repeatCount,
            warmupSeconds: hasWarmup ? warmupSeconds : nil,
            cooldownSeconds: hasCooldown ? cooldownSeconds : nil
        )
    }

    /// 마지막 구간의 반대 종류를 붙인다. 달리기 뒤엔 회복, 회복 뒤엔 달리기.
    mutating func appendSegment() {
        if segments.last?.kind == .run {
            segments.append(SegmentDraft(spec: .rest(seconds: 90)))
        } else {
            let lastRun = segments.last { $0.kind == .run }
            segments.append(SegmentDraft(kind: .run, target: lastRun?.target ?? .distance(400)))
        }
    }

    /// 초안을 모델에 쓴다. plan이 nil이면 새로 만든다.
    @discardableResult
    func apply(to plan: IntervalPlan?, in context: ModelContext) -> IntervalPlan {
        let result = self.blueprint
        let target: IntervalPlan
        if let plan {
            target = plan
            // 관계에서만 떼어내면 고아 Segment가 남는다. 명시적으로 지운다.
            for segment in plan.segments {
                context.delete(segment)
            }
            target.name = result.name
            target.repeatCount = result.repeatCount
            target.warmupSeconds = result.warmupSeconds
            target.cooldownSeconds = result.cooldownSeconds
        } else {
            target = IntervalPlan(
                name: result.name,
                repeatCount: result.repeatCount,
                warmupSeconds: result.warmupSeconds,
                cooldownSeconds: result.cooldownSeconds
            )
            context.insert(target)
        }
        target.replaceSegments(with: result.segments)
        return target
    }
}
