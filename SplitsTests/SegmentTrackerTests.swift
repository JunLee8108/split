//
//  SegmentTrackerTests.swift
//  SplitsTests
//

import Foundation
import Testing
@testable import Splits

struct SegmentTrackerTests {
    private func step(_ target: SegmentTarget, kind: StepKind = .run) -> WorkoutStep {
        WorkoutStep(kind: kind, target: target, index: 0, ordinal: 1, ordinalTotal: 1)
    }

    @Test func distanceStepCompletesOnDistanceOnly() {
        var tracker = SegmentTracker(step: step(.distance(400)))
        tracker.add(time: 600)
        #expect(!tracker.isComplete)
        #expect(tracker.remaining == 400)

        tracker.add(distance: 250)
        #expect(tracker.remaining == 150)
        #expect(abs(tracker.progress - 0.625) < 0.0001)

        tracker.add(distance: 160)
        #expect(tracker.isComplete)
        #expect(tracker.remaining == 0)
        #expect(tracker.overflow.distance == 10)
        #expect(tracker.overflow.time == 0)
    }

    @Test func durationStepCompletesOnTimeOnly() {
        var tracker = SegmentTracker(step: step(.duration(90), kind: .rest))
        tracker.add(distance: 5000)
        #expect(!tracker.isComplete)

        tracker.add(time: 89.5)
        #expect(!tracker.isComplete)
        #expect(tracker.remaining == 0.5)

        tracker.add(time: 2)
        #expect(tracker.isComplete)
        #expect(tracker.overflow.time == 1.5)
        #expect(tracker.overflow.distance == 0)
    }

    @Test func carriedValuesCountTowardTarget() {
        let tracker = SegmentTracker(step: step(.duration(60)), carriedDistance: 12, carriedTime: 1.5)
        #expect(tracker.distance == 12)
        #expect(tracker.elapsed == 1.5)
        #expect(tracker.remaining == 58.5)
    }

    @Test func lapRecordKeepsBothMeasures() {
        var tracker = SegmentTracker(step: step(.distance(400)))
        tracker.add(distance: 400)
        tracker.add(time: 100)
        let lap = tracker.lapRecord()
        #expect(lap.distance == 400)
        #expect(lap.duration == 100)
        #expect(lap.pace == 250)
        #expect(lap.kind == .run)
    }

    @Test func negativeInputsAreIgnored() {
        var tracker = SegmentTracker(step: step(.distance(400)))
        tracker.add(distance: -10)
        tracker.add(time: -5)
        #expect(tracker.distance == 0)
        #expect(tracker.elapsed == 0)
    }
}
