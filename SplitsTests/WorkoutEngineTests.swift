//
//  WorkoutEngineTests.swift
//  SplitsTests
//

import Foundation
import Testing
@testable import Splits

@MainActor
struct WorkoutEngineTests {
    private let t0 = Date(timeIntervalSince1970: 2_000_000)

    private func time(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func sample(metersNorth: Double, at seconds: TimeInterval) -> LocationSample {
        LocationSample(
            latitude: 37.5 + metersNorth / 111_195,
            longitude: 127.0,
            timestamp: time(seconds),
            horizontalAccuracy: 5,
            speed: 3
        )
    }

    private func makeEngine(_ blueprint: PlanBlueprint) -> (WorkoutEngine, EventLog) {
        let engine = WorkoutEngine()
        let log = EventLog()
        engine.onEvent = { log.events.append($0) }
        engine.start(planName: blueprint.name, steps: blueprint.steps(), at: t0)
        return (engine, log)
    }

    @Test func startEmitsFirstStep() {
        let (engine, log) = makeEngine(PlanBlueprint(name: "t", segments: [.run(seconds: 60), .rest(seconds: 30)], repeatCount: 2))
        #expect(engine.state == .running)
        #expect(engine.currentStep?.kind == .run)
        #expect(log.events.count == 1)
        if case .stepStarted(let step) = log.events[0] {
            #expect(step.index == 0)
        } else {
            Issue.record("first event should be stepStarted")
        }
    }

    @Test func timeStepsAdvanceWithCountdownAndCarry() {
        // [run 10, rest 5, run 10]. 마지막 회복은 플랜 펼치기에서 빠진다.
        let (engine, log) = makeEngine(PlanBlueprint(name: "t", segments: [.run(seconds: 10), .rest(seconds: 5)], repeatCount: 2))

        for s in 1...4 { engine.tick(now: time(TimeInterval(s))) }
        #expect(log.events.filter { if case .countdown = $0 { true } else { false } }.isEmpty)

        engine.tick(now: time(5))
        #expect(log.events.contains(.countdown(5)))
        for s in 6...9 { engine.tick(now: time(TimeInterval(s))) }
        #expect(log.events.contains(.countdown(1)))

        // 백그라운드에서 늦게 온 틱: 9초 → 11.5초. 목표 10초를 1.5초 넘겼다.
        engine.tick(now: time(11.5))
        #expect(engine.currentIndex == 1)
        #expect(engine.currentStep?.kind == .rest)
        #expect(engine.laps.count == 1)
        #expect(engine.laps[0].duration == 10 + 1.5)  // 랩은 실제 경과를 기록한다
        #expect(engine.tracker?.elapsed == 1.5)       // 넘친 만큼 다음 구간에 이어진다
        #expect(engine.movingTime == 11.5)
    }

    @Test func distanceStepAdvancesOnDistanceAndFinishesSession() {
        let (engine, log) = makeEngine(PlanBlueprint(name: "t", segments: [.run(meters: 100)], repeatCount: 1))

        // 워밍업 5초 뒤부터 유효. 첫 점은 기준점.
        engine.ingest(sample(metersNorth: 0, at: 6))
        engine.ingest(sample(metersNorth: 40, at: 16))
        #expect(engine.totalDistance > 39 && engine.totalDistance < 41)
        #expect(engine.state == .running)
        #expect(log.events.contains { if case .approaching = $0 { true } else { false } })

        engine.ingest(sample(metersNorth: 105, at: 30))
        #expect(engine.state == .finished)
        #expect(engine.laps.count == 1)
        #expect(engine.summary != nil)
        #expect(engine.summary?.totalDistance ?? 0 > 104)
        #expect(engine.route.count == 2)
        if case .finished(let summary)? = log.events.last {
            #expect(summary.laps.count == 1)
        } else {
            Issue.record("last event should be finished")
        }
    }

    @Test func pauseStopsTimeAndDistance() {
        let (engine, _) = makeEngine(PlanBlueprint(name: "t", segments: [.run(seconds: 100)], repeatCount: 1))
        engine.ingest(sample(metersNorth: 0, at: 6))
        engine.tick(now: time(10))
        engine.pause(at: time(12))
        #expect(engine.state == .paused)
        #expect(engine.movingTime == 12)

        // 정지 중 이동은 세지 않는다.
        engine.tick(now: time(40))
        engine.ingest(sample(metersNorth: 200, at: 40))
        #expect(engine.movingTime == 12)
        #expect(engine.totalDistance == 0)

        engine.resume(at: time(50))
        engine.tick(now: time(55))
        #expect(engine.movingTime == 17)

        // 재개 후 첫 이동은 정지 직전이 아니라 정지 중 마지막 위치부터 잰다.
        engine.ingest(sample(metersNorth: 210, at: 55))
        #expect(engine.totalDistance > 9 && engine.totalDistance < 11)
    }

    @Test func skipAdvancesWithoutCarry() {
        let (engine, _) = makeEngine(PlanBlueprint(name: "t", segments: [.run(meters: 400), .rest(seconds: 90)], repeatCount: 2))
        engine.tick(now: time(30))
        engine.skipStep(at: time(30))
        #expect(engine.currentIndex == 1)
        #expect(engine.laps.count == 1)
        #expect(engine.laps[0].duration == 30)
        #expect(engine.tracker?.elapsed == 0)
    }

    @Test func manualFinishRecordsPartialLap() {
        let (engine, _) = makeEngine(PlanBlueprint(name: "t", segments: [.run(seconds: 600)], repeatCount: 3))
        engine.tick(now: time(45))
        let summary = engine.finish(at: time(45))
        #expect(engine.state == .finished)
        #expect(summary?.laps.count == 1)
        #expect(summary?.laps.first?.duration == 45)
        #expect(summary?.movingTime == 45)
        // 끝난 뒤 다시 불러도 같은 요약.
        #expect(engine.finish(at: time(99)) == summary)
    }

    @Test func kilometerEventCarriesSplitPace() {
        let (engine, log) = makeEngine(PlanBlueprint(name: "t", segments: [.run(meters: 3000)], repeatCount: 1))
        engine.ingest(sample(metersNorth: 0, at: 6))
        var meters: Double = 0
        var seconds: TimeInterval = 6
        while meters < 1100 {
            meters += 20
            seconds += 5  // 4 m/s = 4'10"/km
            engine.tick(now: time(seconds))
            engine.ingest(sample(metersNorth: meters, at: seconds))
        }
        let km = log.events.compactMap { event -> (Int, TimeInterval?)? in
            if case .kilometer(let n, let pace) = event { return (n, pace) }
            return nil
        }
        #expect(km.count == 1)
        #expect(km.first?.0 == 1)
        // 첫 1km 스플릿에는 시작 후 기준점까지의 6초가 섞인다. 대략 맞으면 된다.
        #expect((km.first?.1 ?? 0) > 240 && (km.first?.1 ?? 0) < 270)
    }

    @Test func inputsIgnoredWhenIdle() {
        let engine = WorkoutEngine()
        engine.tick(now: t0)
        engine.ingest(sample(metersNorth: 100, at: 10))
        #expect(engine.state == .idle)
        #expect(engine.totalDistance == 0)
        #expect(engine.finish() == nil)
    }
}

@MainActor
private final class EventLog {
    var events: [WorkoutEvent] = []
}
