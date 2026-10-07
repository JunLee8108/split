//
//  SessionReadout.swift
//  Splits
//
//  세션 화면의 큰 숫자 두 개. iPhone과 워치가 같은 값을 같은 말로 보여 준다.
//

import Foundation

nonisolated enum SessionReadout {
    /// 1층: 이 구간을 끝내는 값. 남은 거리 또는 남은 시간.
    static func primary(_ tracker: SegmentTracker?, unit: DistanceUnit) -> (value: String, label: String) {
        guard let tracker else { return ("완료", " ") }
        switch tracker.step.target {
        case .distance:
            return (Formatters.distance(tracker.remaining.rounded(), unit: unit), "남은 거리")
        case .duration:
            return (Formatters.clock(tracker.remaining.rounded(.up)), "남은 시간")
        }
    }

    /// 2층: 목표까지, 없으면 구간 경과.
    static func secondary(_ tracker: SegmentTracker?, unit: DistanceUnit) -> (value: String, label: String) {
        guard let tracker else { return (" ", " ") }
        let step = tracker.step
        if let goal = step.goalValue {
            let pace = Formatters.pace(step.goalPace, unit: unit)
            switch step.target {
            case .distance:
                let remaining = goal - tracker.elapsed
                if remaining >= 0 {
                    return (Formatters.clock(remaining.rounded(.up)), "목표까지 · \(pace)")
                }
                return ("+\(Formatters.clock(-remaining))", "목표 초과 · \(pace)")
            case .duration:
                let remaining = goal - tracker.distance
                if remaining >= 0 {
                    return (Formatters.distance(remaining.rounded(), unit: unit), "목표까지 · \(pace)")
                }
                return ("+\(Formatters.distance(-remaining, unit: unit))", "목표 초과 · \(pace)")
            }
        }
        // 목표가 없으면 1층과 반대 축을 보여 준다. 거리 구간이면 경과 시간, 시간 구간이면 달린 거리.
        switch step.target {
        case .distance:
            return (Formatters.clock(tracker.elapsed), "구간 경과")
        case .duration:
            return (Formatters.distance(tracker.distance, unit: unit), "구간 거리")
        }
    }
}
