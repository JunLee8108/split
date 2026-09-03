//
//  GoalTests.swift
//  SplitsTests
//

import Foundation
import Testing
@testable import Splits

struct GoalTests {
    @Test func blueprintCarriesGoalIntoSteps() {
        var run = SegmentSpec.run(meters: 400)
        run.goalValue = 90
        let plan = PlanBlueprint(name: "t", segments: [run, .rest(seconds: 60)], repeatCount: 2)
        let steps = plan.steps()
        #expect(steps[0].goalValue == 90)
        #expect(steps[1].goalValue == nil)
        #expect(steps[2].goalValue == 90)
        #expect(steps[0].goalPace == 225)
    }

    @Test func goalDeltaForDistanceSegment() {
        let fast = LapRecord(index: 0, kind: .run, target: .distance(400), distance: 400, duration: 88, goalValue: 90)
        #expect(fast.goalDelta == -2)
        #expect(fast.goalMet == true)
        #expect(Formatters.goalDelta(fast) == "−0:02")

        let slow = LapRecord(index: 1, kind: .run, target: .distance(400), distance: 400, duration: 95, goalValue: 90)
        #expect(slow.goalDelta == 5)
        #expect(slow.goalMet == false)
        #expect(Formatters.goalDelta(slow) == "+0:05")
    }

    @Test func goalDeltaForDurationSegment() {
        let far = LapRecord(index: 0, kind: .run, target: .duration(180), distance: 840, duration: 180, goalValue: 800)
        #expect(far.goalDelta == 40)
        #expect(far.goalMet == true)
        #expect(Formatters.goalDelta(far) == "+40 m")

        let short = LapRecord(index: 1, kind: .run, target: .duration(180), distance: 785, duration: 180, goalValue: 800)
        #expect(short.goalMet == false)
        #expect(Formatters.goalDelta(short) == "−15 m")
    }

    @Test func noGoalMeansNoDelta() {
        let lap = LapRecord(index: 0, kind: .run, target: .distance(400), distance: 400, duration: 90)
        #expect(lap.goalDelta == nil)
        #expect(lap.goalMet == nil)
        #expect(Formatters.goalDelta(lap) == nil)
    }

    @Test func goalSummaryCountsRunLapsOnly() {
        let laps = [
            LapRecord(index: 0, kind: .run, target: .distance(400), distance: 400, duration: 88, goalValue: 90),
            LapRecord(index: 1, kind: .rest, target: .duration(60), distance: 100, duration: 60, goalValue: 50),
            LapRecord(index: 2, kind: .run, target: .distance(400), distance: 400, duration: 95, goalValue: 90),
            LapRecord(index: 3, kind: .run, target: .distance(400), distance: 400, duration: 95),
        ]
        let summary = GoalSummary.compute(for: laps)
        #expect(summary?.met == 1)
        #expect(summary?.total == 2)
        #expect(GoalSummary.compute(for: [laps[3]]) == nil)
    }

    @Test func paceTableMatchesReference() {
        let rows = PaceTable.rows(meters: 400)
        #expect(rows.first?.seconds == 60)
        #expect(rows.last?.seconds == 240)
        let ninety = rows.first { $0.seconds == 90 }
        #expect(ninety?.paceKm == 225)
        #expect(Formatters.pace(ninety?.paceKm) == "3'45\"")
        #expect(Formatters.pace(ninety?.paceKm, unit: .imperial) == "6'02\"")

        let twoHundred = PaceTable.rows(meters: 200)
        let seventy = twoHundred.first { $0.seconds == 70 }
        #expect(Formatters.pace(seventy?.paceKm) == "5'50\"")
        #expect(Formatters.pace(seventy?.paceKm, unit: .imperial) == "9'23\"")
    }

    @Test func paceTableWidensStepForLongDistances() {
        let rows = PaceTable.rows(meters: 10000)
        #expect(rows.count <= 61)
        #expect(rows.count > 10)
    }

    @Test func paceBothFormatting() {
        #expect(Formatters.paceBoth(225) == "3'45\"/km · 6'02\"/mi")
        #expect(Formatters.paceBoth(nil) == "—")
    }
}

@MainActor
struct GoalEngineTests {
    private let t0 = Date(timeIntervalSince1970: 3_000_000)

    @Test func lapCompletedCarriesGoalAndOrdinal() {
        var run = SegmentSpec.run(seconds: 10)
        run.goalValue = 50
        let plan = PlanBlueprint(name: "t", segments: [run, .rest(seconds: 5)], repeatCount: 2)

        let engine = WorkoutEngine()
        var completed: [LapRecord] = []
        engine.onEvent = { event in
            if case .lapCompleted(let lap) = event { completed.append(lap) }
        }
        engine.start(planName: plan.name, steps: plan.steps(), at: t0)
        engine.tick(now: t0.addingTimeInterval(10))

        #expect(completed.count == 1)
        #expect(completed.first?.goalValue == 50)
        #expect(completed.first?.ordinal == 1)
        #expect(completed.first?.kind == .run)
    }

    @Test func announcerPhraseForGoal() {
        let announcer = Announcer()
        let fast = LapRecord(index: 0, kind: .run, target: .distance(400), distance: 400, duration: 88, goalValue: 90, ordinal: 3)
        #expect(announcer.resultPhrase(for: fast) == "3번째 달리기, 1분 28초, 목표보다 2초 빠름")
        let rest = LapRecord(index: 1, kind: .rest, target: .duration(60), distance: 0, duration: 60, goalValue: 50, ordinal: 1)
        #expect(announcer.resultPhrase(for: rest) == nil)
        let noGoal = LapRecord(index: 2, kind: .run, target: .distance(400), distance: 400, duration: 88, ordinal: 2)
        #expect(announcer.resultPhrase(for: noGoal) == nil)
    }

    @Test func lapTableGroupsBySet() {
        let laps = [
            LapRecord(index: 0, kind: .warmup, target: .duration(300), distance: 500, duration: 300),
            LapRecord(index: 1, kind: .run, target: .distance(400), distance: 400, duration: 95, setIndex: 1),
            LapRecord(index: 2, kind: .rest, target: .distance(200), distance: 200, duration: 66, setIndex: 1),
            LapRecord(index: 3, kind: .run, target: .distance(400), distance: 400, duration: 103, setIndex: 2),
            LapRecord(index: 4, kind: .cooldown, target: .duration(120), distance: 200, duration: 120),
        ]
        let rows = LapTableLayout.rows(for: laps)
        #expect(rows.map(\.number) == [nil, "1", nil, "2", nil])
        #expect(rows.map(\.startsSet) == [false, false, false, true, false])
    }

    @Test func lapTableFallsBackToSequenceForOldRecords() {
        let laps = [
            LapRecord(index: 0, kind: .run, target: .distance(400), distance: 400, duration: 95),
            LapRecord(index: 1, kind: .rest, target: .duration(90), distance: 0, duration: 90),
        ]
        #expect(!LapTableLayout.isGrouped(laps))
        #expect(LapTableLayout.rows(for: laps).map(\.number) == ["1", "2"])
    }
}

struct ShareTextTests {
    @Test func summaryHasHeadlineStatsAndRuns() {
        let laps = [
            LapRecord(index: 0, kind: .warmup, target: .duration(300), distance: 600, duration: 300),
            LapRecord(index: 1, kind: .run, target: .distance(400), distance: 400, duration: 95, goalValue: 100, setIndex: 1),
            LapRecord(index: 2, kind: .rest, target: .distance(200), distance: 200, duration: 66, setIndex: 1),
            LapRecord(index: 3, kind: .run, target: .distance(400), distance: 400, duration: 103, goalValue: 100, setIndex: 2),
        ]
        let workout = ShareableWorkout(
            planName: "400m × 2",
            startedAt: Date(timeIntervalSince1970: 1_756_800_000),
            totalDistance: 1600,
            movingTime: 564,
            laps: laps,
            route: []
        )
        let text = ShareText.summary(workout)
        let lines = text.split(separator: "\n").map(String.init)
        #expect(lines.count == 5)
        #expect(lines[0].hasPrefix("400m × 2 · "))
        #expect(lines[1] == "1.60 km · 9:24 · 5'52\"/km")
        #expect(lines[2] == "달리기 2: 1:35 · 1:43")
        #expect(lines[3] == "목표 달성 1 / 2")
        #expect(lines[4] == "Splits")
    }
}
