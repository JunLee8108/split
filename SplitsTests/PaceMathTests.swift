//
//  PaceMathTests.swift
//  SplitsTests
//

import Foundation
import Testing
@testable import Splits

/// 위도 37.5 부근에서 북쪽으로 `meters`만큼 이동한 점을 만든다.
private func sample(
    metersNorth: Double,
    at seconds: TimeInterval,
    accuracy: Double = 5,
    speed: Double = 3,
    stationary: Bool = false,
    origin: Date = Date(timeIntervalSince1970: 1_000_000)
) -> LocationSample {
    LocationSample(
        latitude: 37.5 + metersNorth / 111_195,
        longitude: 127.0,
        timestamp: origin.addingTimeInterval(seconds),
        horizontalAccuracy: accuracy,
        speed: speed,
        isStationary: stationary
    )
}

struct PaceMathTests {
    @Test func haversineIsRoughlyRight() {
        let a = sample(metersNorth: 0, at: 0)
        let b = sample(metersNorth: 400, at: 100)
        let d = PaceMath.distance(from: a, to: b)
        #expect(abs(d - 400) < 1)
    }

    @Test func paceNeedsMinimumDistance() {
        #expect(PaceMath.pace(distance: 1000, duration: 270) == 270)
        #expect(PaceMath.pace(distance: 2, duration: 10) == nil)
        #expect(PaceMath.pace(distance: 100, duration: 0) == nil)
    }
}

struct DistanceAccumulatorTests {
    private let origin = Date(timeIntervalSince1970: 1_000_000)

    @Test func accumulatesAlongAPath() {
        var acc = DistanceAccumulator()
        acc.start(at: origin)
        var total: Double = 0
        for i in 0...10 {
            total += acc.ingest(sample(metersNorth: Double(i) * 30, at: 10 + Double(i) * 10))
        }
        #expect(abs(total - 300) < 2)
    }

    @Test func dropsInaccuratePoints() {
        var acc = DistanceAccumulator()
        acc.start(at: origin)
        _ = acc.ingest(sample(metersNorth: 0, at: 10))
        let d1 = acc.ingest(sample(metersNorth: 100, at: 20, accuracy: 45))
        let d2 = acc.ingest(sample(metersNorth: 100, at: 30, accuracy: -1))
        #expect(d1 == 0)
        #expect(d2 == 0)
        let d3 = acc.ingest(sample(metersNorth: 100, at: 40))
        #expect(abs(d3 - 100) < 1)
    }

    @Test func dropsWarmupPoints() {
        var acc = DistanceAccumulator()
        acc.start(at: origin)
        _ = acc.ingest(sample(metersNorth: 0, at: 1))
        let early = acc.ingest(sample(metersNorth: 50, at: 3))
        #expect(early == 0)
        // 첫 유효 점은 기준점이 되고 거리는 0.
        #expect(acc.ingest(sample(metersNorth: 50, at: 6)) == 0)
        #expect(abs(acc.ingest(sample(metersNorth: 100, at: 16)) - 50) < 1)
    }

    @Test func stationaryPointsDoNotMoveTheReference() {
        var acc = DistanceAccumulator()
        acc.start(at: origin)
        _ = acc.ingest(sample(metersNorth: 0, at: 10))
        #expect(acc.ingest(sample(metersNorth: 3, at: 20, speed: 0.1)) == 0)
        #expect(acc.ingest(sample(metersNorth: 6, at: 30, stationary: true)) == 0)
        // 다시 움직이면 원래 기준점부터 잰다.
        #expect(abs(acc.ingest(sample(metersNorth: 30, at: 40)) - 30) < 1)
    }

    @Test func dropsImplausibleJumps() {
        var acc = DistanceAccumulator()
        acc.start(at: origin)
        _ = acc.ingest(sample(metersNorth: 0, at: 10))
        #expect(acc.ingest(sample(metersNorth: 500, at: 11)) == 0)
        #expect(abs(acc.ingest(sample(metersNorth: 20, at: 20)) - 20) < 1)
    }

    @Test func pausedIngestMovesReferenceWithoutCounting() {
        var acc = DistanceAccumulator()
        acc.start(at: origin)
        _ = acc.ingest(sample(metersNorth: 0, at: 10))
        #expect(acc.ingest(sample(metersNorth: 200, at: 60), accumulate: false) == 0)
        #expect(abs(acc.ingest(sample(metersNorth: 210, at: 70)) - 10) < 1)
    }
}

struct PaceCalculatorTests {
    private let origin = Date(timeIntervalSince1970: 1_000_000)

    @Test func averagesOverTheWindow() {
        var calc = PaceCalculator()
        // 4'10"/km = 4 m/s
        for i in 0...20 {
            calc.record(cumulativeDistance: Double(i) * 4, at: origin.addingTimeInterval(Double(i)))
        }
        let pace = calc.pace(at: origin.addingTimeInterval(20))
        #expect(pace != nil)
        #expect(abs((pace ?? 0) - 250) < 1)
    }

    @Test func staleDataGivesNil() {
        var calc = PaceCalculator()
        calc.record(cumulativeDistance: 0, at: origin)
        calc.record(cumulativeDistance: 40, at: origin.addingTimeInterval(10))
        #expect(calc.pace(at: origin.addingTimeInterval(12)) != nil)
        #expect(calc.pace(at: origin.addingTimeInterval(30)) == nil)
    }

    @Test func tooLittleDistanceGivesNil() {
        var calc = PaceCalculator()
        calc.record(cumulativeDistance: 0, at: origin)
        calc.record(cumulativeDistance: 2, at: origin.addingTimeInterval(10))
        #expect(calc.pace(at: origin.addingTimeInterval(10)) == nil)
    }
}
