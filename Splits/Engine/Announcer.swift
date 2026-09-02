//
//  Announcer.swift
//  Splits
//
//  엔진 이벤트를 한국어 음성과 햅틱으로 바꾼다. 문장은 짧게, 숫자는 앞에.
//

import AVFoundation
import Foundation
import UIKit

final class Announcer {
    var isVoiceEnabled = true
    var unit: DistanceUnit = .metric

    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "ko-KR")
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let notification = UINotificationFeedbackGenerator()

    /// 세션 시작 때 한 번. 음악 위에 안내가 얹히도록 duckOthers.
    func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        heavyImpact.prepare()
        lightImpact.prepare()
        notification.prepare()
    }

    /// 말하던 안내("완료, ...")가 끝난 뒤에 세션을 내린다. 최대 10초까지만 기다린다.
    func deactivateAudioSession() {
        Task { [synthesizer] in
            var waited = 0
            while synthesizer.isSpeaking, waited < 20 {
                try? await Task.sleep(for: .milliseconds(500))
                waited += 1
            }
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    func handle(_ event: WorkoutEvent) {
        switch event {
        case .lapCompleted(let lap):
            // 목표가 있는 달리기 구간만 결과를 읽는다. 없으면 다음 구간 안내로 충분하다.
            if let phrase = resultPhrase(for: lap) {
                speak(phrase)
            }

        case .stepStarted(let step):
            speak(phrase(for: step))
            switch step.kind {
            case .run, .warmup:
                heavyImpact.impactOccurred()
                Task { [heavyImpact] in
                    try? await Task.sleep(for: .milliseconds(250))
                    heavyImpact.impactOccurred()
                }
            case .rest, .cooldown:
                heavyImpact.impactOccurred(intensity: 1.0)
            }

        case .countdown(let seconds):
            speak("\(seconds)", interrupting: true)

        case .approaching(let remaining):
            speak("\(Formatters.spokenDistance(remaining.rounded(), unit: unit)) 남음")

        case .kilometer(let count, let splitPace):
            var text = Formatters.spokenDistance(Double(count) * 1000, unit: unit)
            if let spoken = Formatters.spokenPace(splitPace, unit: unit) {
                text += ", \(spoken)"
            }
            speak(text)
            lightImpact.impactOccurred()

        case .paused:
            speak("일시정지")
            lightImpact.impactOccurred()

        case .resumed:
            speak("재개")
            lightImpact.impactOccurred()

        case .finished(let summary):
            var text = "완료. \(Formatters.spokenDistance(summary.totalDistance, unit: unit))"
            if let spoken = Formatters.spokenPace(summary.averagePace, unit: unit) {
                text += ", 평균 \(spoken)"
            }
            speak(text)
            notification.notificationOccurred(.success)
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

    func speak(_ text: String, interrupting: Bool = false) {
        guard isVoiceEnabled else { return }
        if interrupting, synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }
}
