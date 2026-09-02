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
