//
//  PaceMath.swift
//  Splits
//
//  CoreLocation에 의존하지 않는 거리·페이스 계산. 전부 테스트 가능하다.
//

import Foundation

/// LocationManager가 CLLocation을 이 값으로 바꿔 엔진에 넘긴다.
nonisolated struct LocationSample: Hashable, Sendable {
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    /// 미터. 음수면 무효.
    var horizontalAccuracy: Double
    /// m/s. 음수면 알 수 없음.
    var speed: Double
    var isStationary: Bool = false
}

nonisolated enum PaceMath {
    static let earthRadius: Double = 6_371_000

    /// 두 좌표 사이 거리(미터). 하버사인.
    static func distance(from a: LocationSample, to b: LocationSample) -> Double {
        distance(lat1: a.latitude, lon1: a.longitude, lat2: b.latitude, lon2: b.longitude)
    }

    static func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let φ1 = lat1 * .pi / 180
        let φ2 = lat2 * .pi / 180
        let dφ = (lat2 - lat1) * .pi / 180
        let dλ = (lon2 - lon1) * .pi / 180
        let a = sin(dφ / 2) * sin(dφ / 2) + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }

    /// 초/km. 거리가 5m 미만이면 nil.
    static func pace(distance: Double, duration: TimeInterval) -> TimeInterval? {
        guard distance >= 5, duration > 0 else { return nil }
        return duration / (distance / 1000)
    }
}

/// GPS 점을 받아 실제 이동 거리만 누적한다.
///
/// 규칙
/// - 정확도가 `minimumAccuracy`보다 나쁜 점은 버린다.
/// - 시작 후 `warmupInterval` 동안의 점은 버린다. 콜드 스타트 튐 방지.
/// - 정지 상태(속도 < `stationarySpeed` 또는 isStationary)면 누적하지 않고 기준점도 갱신하지 않는다.
/// - 기준점 대비 속도가 `maximumSpeed`를 넘는 점은 글리치로 보고 버린다.
nonisolated struct DistanceAccumulator: Sendable {
    var minimumAccuracy: Double = 20
    var warmupInterval: TimeInterval = 5
    var stationarySpeed: Double = 0.5
    var maximumSpeed: Double = 12

    private(set) var startedAt: Date?
    private(set) var reference: LocationSample?

    init() {}

    mutating func start(at date: Date) {
        startedAt = date
        reference = nil
    }

    /// 새 점을 반영하고 늘어난 거리(미터)를 돌려준다.
    /// `accumulate`가 false면 기준점만 옮기고 0을 돌려준다. 일시정지 중에 쓴다.
    mutating func ingest(_ sample: LocationSample, accumulate: Bool = true) -> Double {
        guard sample.horizontalAccuracy >= 0, sample.horizontalAccuracy <= minimumAccuracy else {
            return 0
        }
        if let startedAt, sample.timestamp.timeIntervalSince(startedAt) < warmupInterval {
            return 0
        }
        guard let reference else {
            self.reference = sample
            return 0
        }

        if sample.isStationary || (sample.speed >= 0 && sample.speed < stationarySpeed) {
            return 0
        }

        let meters = PaceMath.distance(from: reference, to: sample)
        let seconds = sample.timestamp.timeIntervalSince(reference.timestamp)
        if seconds > 0, meters / seconds > maximumSpeed {
            return 0
        }

        self.reference = sample
        return accumulate ? meters : 0
    }
}

/// 최근 몇 초의 이동 평균으로 현재 페이스를 낸다. 순간값은 너무 튄다.
nonisolated struct PaceCalculator: Sendable {
    var window: TimeInterval = 15
    /// 이 시간 안에 새 점이 없으면 페이스를 모른다고 본다.
    var staleAfter: TimeInterval = 5
    var minimumDistance: Double = 5

    private var samples: [(time: Date, distance: Double)] = []

    init() {}

    mutating func reset() {
        samples.removeAll()
    }

    /// 누적 거리(미터)와 시각을 기록한다.
    mutating func record(cumulativeDistance: Double, at time: Date) {
        samples.append((time, cumulativeDistance))
        let cutoff = time.addingTimeInterval(-window)
        // 창 밖의 점은 지우되, 창 경계 바로 앞의 점 하나는 남겨 창 전체를 덮게 한다.
        while samples.count > 2, samples[1].time < cutoff {
            samples.removeFirst()
        }
    }

    /// 초/km. 데이터가 부족하거나 오래됐으면 nil.
    func pace(at now: Date) -> TimeInterval? {
        guard let first = samples.first, let last = samples.last, samples.count >= 2 else { return nil }
        if now.timeIntervalSince(last.time) > staleAfter { return nil }
        let meters = last.distance - first.distance
        let seconds = last.time.timeIntervalSince(first.time)
        guard meters >= minimumDistance, seconds > 0 else { return nil }
        return seconds / (meters / 1000)
    }
}
