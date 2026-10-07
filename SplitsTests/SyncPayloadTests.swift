//
//  SyncPayloadTests.swift
//  SplitsTests
//

import Foundation
import Testing
@testable import Splits

struct SyncPayloadTests {
    private let settings = SessionSettings(
        unit: .imperial,
        voiceEnabled: false,
        countdownSeconds: 7,
        timeMilestonesEnabled: true,
        saveToHealth: true
    )

    @Test func watchContextRoundTrips() throws {
        let plan = PlanBlueprint(
            name: "400m × 12",
            segments: [
                SegmentSpec(kind: .run, target: .distance(400), goalValue: 90),
                .rest(meters: 200),
            ],
            repeatCount: 12,
            warmupSeconds: 300,
            cooldownSeconds: nil
        )
        let context = WatchContext(plans: [plan], lastPlanName: plan.name, settings: settings)

        let decoded = try SyncCoding.decode(WatchContext.self, from: SyncCoding.encode(context))

        #expect(decoded == context)
        #expect(decoded.plans.first?.steps() == plan.steps())
    }

    @Test func sameContextEncodesToSameBytes() throws {
        let context = WatchContext(plans: [], lastPlanName: "", settings: settings)
        #expect(try SyncCoding.encode(context) == SyncCoding.encode(context))
    }

    @Test func workoutSummaryRoundTrips() throws {
        let start = Date(timeIntervalSince1970: 2_000_000)
        let summary = WorkoutSummary(
            planName: "3분 / 1분 × 6",
            startedAt: start,
            endedAt: start.addingTimeInterval(1500),
            totalDistance: 4210,
            movingTime: 1440,
            laps: [
                LapRecord(index: 0, kind: .run, target: .duration(180), distance: 760, duration: 180, goalValue: 750, ordinal: 1, setIndex: 1),
                LapRecord(index: 1, kind: .rest, target: .duration(60), distance: 150, duration: 60, ordinal: 1, setIndex: 1),
            ],
            route: [
                RoutePoint(latitude: 37.5, longitude: 127.0, timestamp: start.addingTimeInterval(6), stepIndex: 0),
                RoutePoint(latitude: 37.501, longitude: 127.0, timestamp: start.addingTimeInterval(30), stepIndex: 0),
            ]
        )

        let decoded = try SyncCoding.decode(WorkoutSummary.self, from: SyncCoding.encode(summary))

        #expect(decoded == summary)
        #expect(decoded.laps.first?.goalMet == true)
    }
}
