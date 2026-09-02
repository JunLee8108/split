//
//  Formatters.swift
//  Splits
//
//  화면과 음성에 쓰는 문자열 변환. 모델과 엔진은 단위를 모른다. 여기서만 바꾼다.
//

import Foundation

nonisolated enum Formatters {
    static let metersPerMile = 1609.344

    // MARK: 시간

    /// 1:30, 12:05, 1:02:03
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded(.down)), 0)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// 음성용: 1분 30초, 3분, 45초, 1시간 5분
    static func spokenDuration(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded()), 0)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)시간") }
        if m > 0 { parts.append("\(m)분") }
        if s > 0 || parts.isEmpty { parts.append("\(s)초") }
        return parts.joined(separator: " ")
    }

    // MARK: 거리

    /// 400 m, 1.85 km / 0.25 mi
    static func distance(_ meters: Double, unit: DistanceUnit = .metric) -> String {
        switch unit {
        case .metric:
            if meters < 1000 {
                return "\(Int(meters.rounded())) m"
            }
            return String(format: "%.2f km", meters / 1000)
        case .imperial:
            return String(format: "%.2f mi", meters / metersPerMile)
        }
    }

    /// 큰 숫자 표시용, 단위 없이. 1km 미만은 정수 m, 이상은 소수 둘째 자리 km.
    static func distanceValue(_ meters: Double, unit: DistanceUnit = .metric) -> (value: String, unit: String) {
        switch unit {
        case .metric:
            if meters < 1000 {
                return ("\(Int(meters.rounded()))", "m")
            }
            return (String(format: "%.2f", meters / 1000), "km")
        case .imperial:
            return (String(format: "%.2f", meters / metersPerMile), "mi")
        }
    }

    /// 음성용: 400미터, 1킬로미터, 1.5킬로미터
    static func spokenDistance(_ meters: Double, unit: DistanceUnit = .metric) -> String {
        switch unit {
        case .metric:
            if meters < 1000 {
                return "\(Int(meters.rounded()))미터"
            }
            let km = meters / 1000
            if km == km.rounded() {
                return "\(Int(km))킬로미터"
            }
            return String(format: "%.1f킬로미터", km)
        case .imperial:
            let miles = meters / metersPerMile
            if miles == miles.rounded() {
                return "\(Int(miles))마일"
            }
            return String(format: "%.1f마일", miles)
        }
    }

    // MARK: 페이스

    /// 4'32" 또는 — . 입력은 초/km.
    static func pace(_ secondsPerKm: TimeInterval?, unit: DistanceUnit = .metric) -> String {
        guard let secondsPerKm, secondsPerKm.isFinite, secondsPerKm > 0 else { return "—" }
        let perUnit = unit == .metric ? secondsPerKm : secondsPerKm * metersPerMile / 1000
        let total = Int(perUnit.rounded())
        return String(format: "%d'%02d\"", total / 60, total % 60)
    }

    /// 음성용: 4분 28초
    static func spokenPace(_ secondsPerKm: TimeInterval?, unit: DistanceUnit = .metric) -> String? {
        guard let secondsPerKm, secondsPerKm.isFinite, secondsPerKm > 0 else { return nil }
        let perUnit = unit == .metric ? secondsPerKm : secondsPerKm * metersPerMile / 1000
        return spokenDuration(perUnit)
    }

    // MARK: 구간

    /// 400 m / 1:30 같은 목표 표기.
    static func target(_ target: SegmentTarget, unit: DistanceUnit = .metric) -> String {
        switch target {
        case .distance(let m): distance(m, unit: unit)
        case .duration(let s): clock(s)
        }
    }

    static func spokenTarget(_ target: SegmentTarget, unit: DistanceUnit = .metric) -> String {
        switch target {
        case .distance(let m): spokenDistance(m, unit: unit)
        case .duration(let s): spokenDuration(s)
        }
    }

    /// 목표값 표기. 거리 구간의 목표는 시간, 시간 구간의 목표는 거리.
    static func goal(_ target: SegmentTarget, goalValue: Double, unit: DistanceUnit = .metric) -> String {
        switch target {
        case .distance: clock(goalValue)
        case .duration: distance(goalValue, unit: unit)
        }
    }

    /// 3'45"/km · 6'02"/mi
    static func paceBoth(_ secondsPerKm: TimeInterval?) -> String {
        guard let secondsPerKm, secondsPerKm.isFinite, secondsPerKm > 0 else { return "—" }
        return "\(pace(secondsPerKm, unit: .metric))/km · \(pace(secondsPerKm, unit: .imperial))/mi"
    }

    /// 목표 대비 차이. −0:02, +0:05, +40 m, −15 m. 없으면 nil.
    static func goalDelta(_ lap: LapRecord, unit: DistanceUnit = .metric) -> String? {
        guard let delta = lap.goalDelta else { return nil }
        let sign = delta < 0 ? "−" : "+"
        switch lap.target {
        case .distance:
            return "\(sign)\(clock(abs(delta)))"
        case .duration:
            return "\(sign)\(distance(abs(delta), unit: unit))"
        }
    }

    /// 플랜 목록 한 줄 요약. "RUN 400 m · REST 1:30 · 총 4.0 km"
    static func planSummary(_ blueprint: PlanBlueprint, unit: DistanceUnit = .metric) -> String {
        var parts = blueprint.segments.map { "\($0.kind.badge) \(target($0.target, unit: unit))" }
        let plannedDistance = blueprint.plannedDistance
        let plannedDuration = blueprint.plannedDuration
        if plannedDistance > 0 && plannedDuration > 0 {
            parts.append("총 \(distance(plannedDistance, unit: unit)) + \(clock(plannedDuration))")
        } else if plannedDistance > 0 {
            parts.append("총 \(distance(plannedDistance, unit: unit))")
        } else if plannedDuration > 0 {
            parts.append("총 \(clock(plannedDuration))")
        }
        return parts.joined(separator: " · ")
    }
}
