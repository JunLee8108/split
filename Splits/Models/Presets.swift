//
//  Presets.swift
//  Splits
//
//  첫 실행 때 넣어 주는 기본 플랜.
//

import Foundation
import SwiftData

enum Presets {
    static let blueprints: [PlanBlueprint] = [
        PlanBlueprint(
            name: "400m × 8",
            segments: [.run(meters: 400), .rest(seconds: 90)],
            repeatCount: 8
        ),
        PlanBlueprint(
            name: "3분 / 1분 × 6",
            segments: [.run(seconds: 180), .rest(seconds: 60)],
            repeatCount: 6
        ),
        PlanBlueprint(
            name: "1km × 4",
            segments: [.run(meters: 1000), .rest(seconds: 120)],
            repeatCount: 4
        ),
    ]

    private static let insertedKey = "presets.inserted.v1"

    /// 프리셋을 한 번만 넣는다. 사용자가 지운 프리셋은 다시 만들지 않는다.
    static func insertIfNeeded(into context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: insertedKey) else { return }

        let base = Date.now
        for (offset, blueprint) in blueprints.enumerated() {
            // 목록이 프리셋 순서대로 보이도록 생성 시각을 1초씩 띄운다.
            let plan = IntervalPlan(
                name: blueprint.name,
                repeatCount: blueprint.repeatCount,
                warmupSeconds: blueprint.warmupSeconds,
                cooldownSeconds: blueprint.cooldownSeconds,
                isPreset: true,
                createdAt: base.addingTimeInterval(TimeInterval(offset))
            )
            context.insert(plan)
            plan.replaceSegments(with: blueprint.segments)
        }

        defaults.set(true, forKey: insertedKey)
    }
}
