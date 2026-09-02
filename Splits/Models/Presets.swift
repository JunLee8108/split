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
            name: "400m × 12",
            segments: [.run(meters: 400), .rest(meters: 200)],
            repeatCount: 12,
            warmupSeconds: 300,
            cooldownSeconds: 300
        ),
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

    private static let legacyInsertedKey = "presets.inserted.v1"
    private static let insertedNamesKey = "presets.insertedNames"

    /// 아직 넣지 않은 프리셋만 넣는다. 사용자가 지운 프리셋은 다시 만들지 않는다.
    static func insertIfNeeded(into context: ModelContext) {
        let defaults = UserDefaults.standard
        var inserted = Set(defaults.stringArray(forKey: insertedNamesKey) ?? [])

        // v1 플래그만 있는 설치: 그때 있던 세 개는 이미 들어간 것으로 본다.
        if inserted.isEmpty, defaults.bool(forKey: legacyInsertedKey) {
            inserted = ["400m × 8", "3분 / 1분 × 6", "1km × 4"]
        }

        let base = Date.now
        for (offset, blueprint) in blueprints.enumerated() where !inserted.contains(blueprint.name) {
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
            inserted.insert(blueprint.name)
        }

        defaults.set(Array(inserted), forKey: insertedNamesKey)
    }
}
