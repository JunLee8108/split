//
//  SegmentTarget.swift
//  Splits
//
//  구간의 종료 기준. 저장 단위는 항상 미터와 초.
//

import Foundation

nonisolated enum StepKind: String, Codable, Sendable, CaseIterable, Hashable {
    case warmup
    case run
    case rest
    case cooldown

    var isRun: Bool { self == .run }

    /// 화면 배지용 짧은 표기.
    var badge: String {
        switch self {
        case .warmup: "WARM"
        case .run: "RUN"
        case .rest: "REST"
        case .cooldown: "COOL"
        }
    }

    /// 음성 안내와 목록에 쓰는 한국어 이름.
    var koreanName: String {
        switch self {
        case .warmup: "워밍업"
        case .run: "달리기"
        case .rest: "회복"
        case .cooldown: "쿨다운"
        }
    }
}

nonisolated enum SegmentTarget: Hashable, Codable, Sendable {
    /// 목표 거리(미터).
    case distance(Double)
    /// 목표 시간(초).
    case duration(TimeInterval)

    var isDistance: Bool {
        if case .distance = self { return true }
        return false
    }

    var meters: Double? {
        if case .distance(let m) = self { return m }
        return nil
    }

    var seconds: TimeInterval? {
        if case .duration(let s) = self { return s }
        return nil
    }

    /// 목표값 자체 (미터 또는 초).
    var value: Double {
        switch self {
        case .distance(let m): m
        case .duration(let s): s
        }
    }

    // SwiftData에는 종류 문자열 + 값으로 나눠 저장한다.
    static let distanceKey = "distance"
    static let durationKey = "duration"

    var storageKind: String {
        isDistance ? Self.distanceKey : Self.durationKey
    }

    init(storageKind: String, value: Double) {
        if storageKind == Self.durationKey {
            self = .duration(value)
        } else {
            self = .distance(value)
        }
    }
}

/// 구간의 목표. 종료 조건이 아니라 "그 안에 얼마나 잘 뛰었나"의 기준이다.
/// 거리 구간이면 목표 시간(초), 시간 구간이면 목표 거리(미터). 값 하나로 저장하고 해석은 target이 정한다.
nonisolated enum GoalMath {
    /// 목표 페이스(초/km).
    static func pace(target: SegmentTarget, goalValue: Double?) -> TimeInterval? {
        guard let goalValue, goalValue > 0 else { return nil }
        switch target {
        case .distance(let meters): return PaceMath.pace(distance: meters, duration: goalValue)
        case .duration(let seconds): return PaceMath.pace(distance: goalValue, duration: seconds)
        }
    }
}
