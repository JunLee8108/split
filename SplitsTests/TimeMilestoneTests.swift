//
//  TimeMilestoneTests.swift
//  SplitsTests
//

import Foundation
import Testing
@testable import Splits

@MainActor
struct TimeMilestoneTests {
    private let t0 = Date(timeIntervalSince1970: 4_000_000)

    private func run(seconds: TimeInterval, countdown: Int = 5, ticks: [TimeInterval]) -> (milestones: [Int], countdown: [Int]) {
        let engine = WorkoutEngine()
        engine.countdownSeconds = countdown
        var milestones: [Int] = []
        var countdowns: [Int] = []
        engine.onEvent = { event in
            switch event {
            case .timeRemaining(let s): milestones.append(s)
            case .countdown(let s): countdowns.append(s)
            default: break
            }
        }
        let plan = PlanBlueprint(name: "t", segments: [.run(seconds: seconds)], repeatCount: 1)
        engine.start(planName: plan.name, steps: plan.steps(), at: t0)
        for tick in ticks {
            engine.tick(now: t0.addingTimeInterval(tick))
        }
        return (milestones, countdowns)
    }

    private func everySecond(upTo seconds: Int) -> [TimeInterval] {
        (1...seconds).map(TimeInterval.init)
    }

    @Test func ninetySecondSegmentReadsAllMilestones() {
        let result = run(seconds: 90, ticks: everySecond(upTo: 89))
        #expect(result.milestones == [60, 30, 10])
        #expect(result.countdown == [5, 4, 3, 2, 1])
    }

    @Test func sixtySecondSegmentSkipsTheOneMinuteMilestone() {
        let result = run(seconds: 60, ticks: everySecond(upTo: 59))
        #expect(result.milestones == [30, 10])
    }

    @Test func lateTickReadsOnlyTheNearestMilestone() {
        // 25초 → 75초로 한 번에 건너뛰면 60과 30을 같이 지난다. 30만 읽고, 이후 10은 정상.
        let result = run(seconds: 90, ticks: [25, 75, 80, 85, 86, 87, 88, 89])
        #expect(result.milestones == [30, 10])
    }

    @Test func jumpIntoCountdownSkipsMilestones() {
        let result = run(seconds: 90, ticks: [25, 87, 88, 89])
        #expect(result.milestones.isEmpty)
        #expect(result.countdown == [3, 2, 1])
    }

    @Test func tenSecondMilestoneYieldsToLongCountdown() {
        let result = run(seconds: 90, countdown: 10, ticks: everySecond(upTo: 89))
        #expect(result.milestones == [60, 30])
        #expect(result.countdown.first == 10)
    }

    @Test func milestonesCanBeDisabled() {
        let engine = WorkoutEngine()
        engine.announcesTimeMilestones = false
        var milestones: [Int] = []
        engine.onEvent = { if case .timeRemaining(let s) = $0 { milestones.append(s) } }
        let plan = PlanBlueprint(name: "t", segments: [.run(seconds: 90)], repeatCount: 1)
        engine.start(planName: plan.name, steps: plan.steps(), at: t0)
        for s in 1...89 { engine.tick(now: t0.addingTimeInterval(TimeInterval(s))) }
        #expect(milestones.isEmpty)
    }

    @Test func milestonesResetPerStep() {
        let result = run(seconds: 90, ticks: everySecond(upTo: 89))
        #expect(result.milestones.count == 3)

        // 두 구간이면 두 번씩.
        let engine = WorkoutEngine()
        var milestones: [Int] = []
        engine.onEvent = { if case .timeRemaining(let s) = $0 { milestones.append(s) } }
        let plan = PlanBlueprint(name: "t", segments: [.run(seconds: 90), .rest(seconds: 90)], repeatCount: 1)
        // [run 90, rest 90] 중 마지막 회복은 빠지므로 repeat 2로 세 구간을 만든다.
        let plan2 = PlanBlueprint(name: "t", segments: plan.segments, repeatCount: 2)
        engine.start(planName: plan2.name, steps: plan2.steps(), at: t0)
        for s in 1...269 { engine.tick(now: t0.addingTimeInterval(TimeInterval(s))) }
        #expect(milestones == [60, 30, 10, 60, 30, 10, 60, 30, 10])
    }

    // MARK: 거리 구간 + 목표 시간

    private func runDistance(goal: TimeInterval, ticks: [TimeInterval]) -> (milestones: [Int], countdown: [Int], exceeded: Int) {
        let engine = WorkoutEngine()
        var milestones: [Int] = []
        var countdowns: [Int] = []
        var exceeded = 0
        engine.onEvent = { event in
            switch event {
            case .goalTimeRemaining(let s): milestones.append(s)
            case .goalCountdown(let s): countdowns.append(s)
            case .goalTimeExceeded: exceeded += 1
            case .timeRemaining, .countdown: Issue.record("distance step must not emit segment-time events")
            default: break
            }
        }
        var run = SegmentSpec.run(meters: 400)
        run.goalValue = goal
        let plan = PlanBlueprint(name: "t", segments: [run], repeatCount: 1)
        engine.start(planName: plan.name, steps: plan.steps(), at: t0)
        for tick in ticks {
            engine.tick(now: t0.addingTimeInterval(tick))
        }
        return (milestones, countdowns, exceeded)
    }

    @Test func distanceStepAnnouncesAgainstGoalTime() {
        let result = runDistance(goal: 120, ticks: everySecond(upTo: 130))
        #expect(result.milestones == [60, 30, 10])
        #expect(result.countdown == [5, 4, 3, 2, 1])
        #expect(result.exceeded == 1)
    }

    @Test func distanceStepWithoutGoalStaysSilent() {
        let engine = WorkoutEngine()
        var events: [WorkoutEvent] = []
        engine.onEvent = { events.append($0) }
        let plan = PlanBlueprint(name: "t", segments: [.run(meters: 400)], repeatCount: 1)
        engine.start(planName: plan.name, steps: plan.steps(), at: t0)
        for s in 1...200 { engine.tick(now: t0.addingTimeInterval(TimeInterval(s))) }
        #expect(events.count == 1)  // stepStarted 뿐
    }
}
