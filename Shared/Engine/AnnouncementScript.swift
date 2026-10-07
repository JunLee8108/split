//
//  AnnouncementScript.swift
//  Splits
//
//  엔진 이벤트를 "무엇을 말하고 어떤 진동을 줄지"로 바꾼다. 소리와 진동을 실제로 내는 건
//  기기마다 다르다. iPhone은 Announcer, 워치는 WatchAnnouncer가 이 결과를 받아 낸다.
//

import Foundation

/// 진동의 의미. 기기마다 가장 가까운 패턴으로 옮긴다.
nonisolated enum AnnouncementHaptic: Hashable, Sendable {
    /// 달리기·워밍업 시작. 강하게 두 번.
    case runStart
    /// 회복·쿨다운 시작. 강하게 한 번.
    case restStart
    /// 목표 시간 초과.
    case warning
    /// 이정표, 1km, 일시정지·재개.
    case light
    /// 종료 직전 숫자 세기. iPhone은 음성만으로 충분해 진동하지 않는다.
    case countdown
    /// 세션 완료.
    case success
}

nonisolated struct Announcement: Hashable, Sendable {
    var text: String?
    /// 말하던 걸 끊고 바로 읽는다. 카운트다운 숫자.
    var interrupting = false
    var haptic: AnnouncementHaptic?
}

/// 문장은 짧게, 숫자는 앞에.
nonisolated struct AnnouncementScript: Sendable {
    var unit: DistanceUnit = .metric

    func announcement(for event: WorkoutEvent) -> Announcement? {
        switch event {
        case .lapCompleted(let lap):
            // 목표가 있는 달리기 구간만 결과를 읽는다. 없으면 다음 구간 안내로 충분하다.
            guard let phrase = resultPhrase(for: lap) else { return nil }
            return Announcement(text: phrase)

        case .stepStarted(let step):
            switch step.kind {
            case .run, .warmup:
                return Announcement(text: phrase(for: step), haptic: .runStart)
            case .rest, .cooldown:
                return Announcement(text: phrase(for: step), haptic: .restStart)
            }

        case .timeRemaining(let seconds):
            return Announcement(text: "\(Formatters.spokenDuration(TimeInterval(seconds))) 남았습니다", haptic: .light)

        case .countdown(let seconds), .goalCountdown(let seconds):
            return Announcement(text: "\(seconds)", interrupting: true, haptic: .countdown)

        case .goalTimeRemaining(let seconds):
            return Announcement(text: "목표까지 \(Formatters.spokenDuration(TimeInterval(seconds)))", haptic: .light)

        case .goalTimeExceeded:
            return Announcement(text: "목표 시간 초과", haptic: .warning)

        case .approaching(let remaining):
            return Announcement(text: "\(Formatters.spokenDistance(remaining.rounded(), unit: unit)) 남았습니다", haptic: .light)

        case .kilometer(let count, let splitPace):
            var text = Formatters.spokenDistance(Double(count) * 1000, unit: unit)
            if let spoken = Formatters.spokenPace(splitPace, unit: unit) {
                text += ", \(spoken)"
            }
            return Announcement(text: text, haptic: .light)

        case .paused:
            return Announcement(text: "일시정지", haptic: .light)

        case .resumed:
            return Announcement(text: "재개", haptic: .light)

        case .finished(let summary):
            var text = "완료. \(Formatters.spokenDistance(summary.totalDistance, unit: unit))"
            if let spoken = Formatters.spokenPace(summary.averagePace, unit: unit) {
                text += ", 평균 \(spoken)"
            }
            return Announcement(text: text, haptic: .success)
        }
    }

    /// "3번째 달리기, 400미터" / "회복, 1분 30초" / "워밍업, 5분"
    func phrase(for step: WorkoutStep) -> String {
        let target = Formatters.spokenTarget(step.target, unit: unit)
        switch step.kind {
        case .run:
            return "\(step.ordinal)번째 달리기, \(target)"
        case .rest:
            return "회복, \(target)"
        case .warmup:
            return "워밍업, \(target)"
        case .cooldown:
            return "쿨다운, \(target)"
        }
    }

    /// "3번째 달리기, 1분 28초, 목표보다 2초 빠름"
    func resultPhrase(for lap: LapRecord) -> String? {
        guard lap.kind == .run, let delta = lap.goalDelta else { return nil }
        var text = "\(lap.ordinal)번째 달리기, \(Formatters.spokenDuration(lap.duration))"
        switch lap.target {
        case .distance:
            let seconds = abs(delta).rounded()
            if seconds < 1 {
                text += ", 목표 정확히"
            } else {
                text += ", 목표보다 \(Formatters.spokenDuration(seconds)) \(delta < 0 ? "빠름" : "느림")"
            }
        case .duration:
            let meters = abs(delta).rounded()
            if meters < 5 {
                text += ", 목표 정확히"
            } else {
                text += ", 목표보다 \(Formatters.spokenDistance(meters, unit: unit)) \(delta > 0 ? "더" : "덜")"
            }
        }
        return text
    }
}
