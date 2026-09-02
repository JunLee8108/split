//
//  Presets.swift
//  Splits
//
//  내장 템플릿. 사용자가 언제든 꺼내 내 플랜으로 복사한다.
//  첫 실행에는 그중 두 개만 자동으로 넣는다.
//

import Foundation
import SwiftData

nonisolated struct PlanTemplate: Identifiable, Hashable, Sendable {
    let blueprint: PlanBlueprint
    /// 한 줄 설명. 어떤 훈련인지, 회복은 어떻게 하는지.
    let note: String

    var id: String { blueprint.name }
    var name: String { blueprint.name }
}

enum Presets {
    static let templates: [PlanTemplate] = [
        PlanTemplate(
            blueprint: PlanBlueprint(
                name: "400m × 12",
                segments: [.run(meters: 400), .rest(meters: 200)],
                repeatCount: 12,
                warmupSeconds: 300,
                cooldownSeconds: 300
            ),
            note: "트랙 스피드 세션. 회복은 200m 조깅, 앞뒤로 5분 워밍업·쿨다운."
        ),
        PlanTemplate(
            blueprint: PlanBlueprint(
                name: "400m × 8",
                segments: [.run(meters: 400), .rest(seconds: 90)],
                repeatCount: 8
            ),
            note: "가장 기본적인 400m 반복. 회복은 서서 90초."
        ),
        PlanTemplate(
            blueprint: PlanBlueprint(
                name: "200m × 10",
                segments: [.run(meters: 200), .rest(meters: 200)],
                repeatCount: 10,
                warmupSeconds: 300,
                cooldownSeconds: 300
            ),
            note: "짧고 빠르게. 200m 전력에 가깝게 뛰고 200m 조깅으로 돌아온다."
        ),
        PlanTemplate(
            blueprint: PlanBlueprint(
                name: "800m × 6",
                segments: [.run(meters: 800), .rest(meters: 400)],
                repeatCount: 6,
                warmupSeconds: 600,
                cooldownSeconds: 300
            ),
            note: "야소 800 스타일. 800m마다 400m 조깅 회복, 워밍업 10분."
        ),
        PlanTemplate(
            blueprint: PlanBlueprint(
                name: "1km × 4",
                segments: [.run(meters: 1000), .rest(seconds: 120)],
                repeatCount: 4
            ),
            note: "1km 반복. 5K 목표 페이스로 뛰고 2분 쉰다."
        ),
        PlanTemplate(
            blueprint: PlanBlueprint(
                name: "3분 / 1분 × 6",
                segments: [.run(seconds: 180), .rest(seconds: 60)],
                repeatCount: 6
            ),
            note: "시간 기반. GPS가 흔들리는 코스에서도 정확하다."
        ),
        PlanTemplate(
            blueprint: PlanBlueprint(
                name: "파틀렉 2분 / 2분 × 8",
                segments: [.run(seconds: 120), .rest(seconds: 120)],
                repeatCount: 8,
                warmupSeconds: 300,
                cooldownSeconds: 300
            ),
            note: "빠르게 2분, 편하게 2분. 어디서든 32분."
        ),
    ]

    /// 첫 실행에 자동으로 넣는 것. 나머지는 템플릿 시트에서 고른다.
    static let initialNames: [String] = ["400m × 12", "3분 / 1분 × 6"]

    static func template(named name: String) -> PlanTemplate? {
        templates.first { $0.name == name }
    }

    /// 템플릿을 내 플랜으로 복사한다.
    @discardableResult
    static func add(_ template: PlanTemplate, into context: ModelContext) -> IntervalPlan {
        let blueprint = template.blueprint
        let plan = IntervalPlan(
            name: blueprint.name,
            repeatCount: blueprint.repeatCount,
            warmupSeconds: blueprint.warmupSeconds,
            cooldownSeconds: blueprint.cooldownSeconds,
            isPreset: true
        )
        context.insert(plan)
        plan.replaceSegments(with: blueprint.segments)
        return plan
    }

    private static let legacyInsertedKey = "presets.inserted.v1"
    private static let insertedNamesKey = "presets.insertedNames"

    /// 초기 템플릿 중 아직 넣지 않은 것만 넣는다. 사용자가 지운 것은 다시 만들지 않는다.
    static func insertInitialIfNeeded(into context: ModelContext) {
        let defaults = UserDefaults.standard
        var inserted = Set(defaults.stringArray(forKey: insertedNamesKey) ?? [])

        // v1 플래그만 있는 설치: 그때 있던 세 개는 이미 들어간 것으로 본다.
        if inserted.isEmpty, defaults.bool(forKey: legacyInsertedKey) {
            inserted = ["400m × 8", "3분 / 1분 × 6", "1km × 4"]
        }

        for name in initialNames where !inserted.contains(name) {
            guard let template = template(named: name) else { continue }
            add(template, into: context)
            inserted.insert(name)
        }

        defaults.set(Array(inserted), forKey: insertedNamesKey)
    }
}
