//
//  PlanBlueprintTests.swift
//  SplitsTests
//

import Foundation
import Testing
@testable import Splits

struct PlanBlueprintTests {
    @Test func expandsRepeatsAndDropsTrailingRest() {
        let plan = PlanBlueprint(name: "400m × 8", segments: [.run(meters: 400), .rest(seconds: 90)], repeatCount: 8)
        let steps = plan.steps()

        #expect(steps.count == 15)
        #expect(steps.first?.kind == .run)
        #expect(steps.last?.kind == .run)
        #expect(steps.filter { $0.kind == .run }.count == 8)
        #expect(steps.filter { $0.kind == .rest }.count == 7)
    }

    @Test func ordinalsCountPerKind() {
        let plan = PlanBlueprint(name: "t", segments: [.run(meters: 400), .rest(seconds: 90)], repeatCount: 3)
        let steps = plan.steps()

        let thirdRun = steps.filter { $0.kind == .run }[2]
        #expect(thirdRun.ordinal == 3)
        #expect(thirdRun.ordinalTotal == 3)
        #expect(thirdRun.index == 4)

        let firstRest = steps.first { $0.kind == .rest }
        #expect(firstRest?.ordinal == 1)
        #expect(firstRest?.ordinalTotal == 2)
    }

    @Test func warmupAndCooldownWrapTheSet() {
        let plan = PlanBlueprint(
            name: "t",
            segments: [.run(seconds: 180), .rest(seconds: 60)],
            repeatCount: 2,
            warmupSeconds: 300,
            cooldownSeconds: 120
        )
        let steps = plan.steps()

        #expect(steps.map(\.kind) == [.warmup, .run, .rest, .run, .cooldown])
        #expect(steps[0].target == .duration(300))
        #expect(steps[4].target == .duration(120))
    }

    @Test func plannedTotals() {
        let distancePlan = PlanBlueprint(name: "t", segments: [.run(meters: 400), .rest(seconds: 90)], repeatCount: 8)
        #expect(distancePlan.plannedDistance == 3200)
        #expect(distancePlan.plannedDuration == 90 * 7)

        let timePlan = PlanBlueprint(name: "t", segments: [.run(seconds: 180), .rest(seconds: 60)], repeatCount: 6)
        #expect(timePlan.plannedDistance == 0)
        #expect(timePlan.plannedDuration == 180 * 6 + 60 * 5)
    }

    @Test func estimatedDurationAddsGoalTimes() {
        var run = SegmentSpec.run(meters: 400)
        run.goalValue = 120
        let plan = PlanBlueprint(
            name: "t",
            segments: [run, .rest(meters: 200)],
            repeatCount: 3,
            warmupSeconds: 300,
            cooldownSeconds: 300
        )
        // 워밍업 300 + 달리기 120×3 + 쿨다운 300. 회복 200m는 목표가 없어 빠진다(2개).
        let estimate = plan.estimatedDuration
        #expect(estimate.seconds == 300 + 360 + 300)
        #expect(estimate.unknownSteps == 2)
        #expect(Formatters.estimatedDuration(plan) == "16:00+")

        var rest = SegmentSpec.rest(meters: 200)
        rest.goalValue = 60
        let complete = PlanBlueprint(name: "t", segments: [run, rest], repeatCount: 3, warmupSeconds: 300, cooldownSeconds: 300)
        #expect(complete.estimatedDuration.unknownSteps == 0)
        #expect(Formatters.estimatedDuration(complete) == "18:00")
    }

    @Test func setIndexFollowsRepetitions() {
        let plan = PlanBlueprint(
            name: "t",
            segments: [.run(meters: 400), .run(meters: 200), .rest(seconds: 60)],
            repeatCount: 2,
            warmupSeconds: 300,
            cooldownSeconds: 120
        )
        let sets = plan.steps().map(\.setIndex)
        // 워밍업 nil, 1세트 3개, 2세트 2개(마지막 회복 제외), 쿨다운 nil
        #expect(sets == [nil, 1, 1, 1, 2, 2, nil])
    }

    @Test func repeatCountNeverBelowOne() {
        let plan = PlanBlueprint(name: "t", segments: [.run(meters: 100)], repeatCount: 0)
        #expect(plan.steps().count == 1)
    }
}

struct FormattersTests {
    @Test func clock() {
        #expect(Formatters.clock(90) == "1:30")
        #expect(Formatters.clock(5) == "0:05")
        #expect(Formatters.clock(3723) == "1:02:03")
    }

    @Test func distance() {
        #expect(Formatters.distance(400) == "400 m")
        #expect(Formatters.distance(1850) == "1.85 km")
        #expect(Formatters.distance(1609.344, unit: .imperial) == "1.00 mi")
    }

    @Test func pace() {
        #expect(Formatters.pace(272) == "4'32\"")
        #expect(Formatters.pace(nil) == "—")
        #expect(Formatters.pace(0) == "—")
    }

    @Test func spoken() {
        #expect(Formatters.spokenDuration(90) == "1분 30초")
        #expect(Formatters.spokenDuration(180) == "3분")
        #expect(Formatters.spokenDistance(400) == "400미터")
        #expect(Formatters.spokenDistance(1000) == "1킬로미터")
        #expect(Formatters.spokenDistance(1500) == "1.5킬로미터")
        #expect(Formatters.spokenPace(268) == "4분 28초")
    }

    @Test func planSummary() {
        let plan = PlanBlueprint(name: "t", segments: [.run(meters: 400), .rest(seconds: 90)], repeatCount: 8)
        #expect(Formatters.planSummary(plan) == "RUN 400 m · REST 1:30 · 총 3.20 km · 약 10:30+")
    }
}
