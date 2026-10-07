//
//  Announcer.swift
//  Splits
//
//  AnnouncementScript가 정한 문장과 진동을 iPhone에서 낸다.
//

import AVFoundation
import Foundation
import UIKit

final class Announcer {
    var isVoiceEnabled = true
    var unit: DistanceUnit {
        get { script.unit }
        set { script.unit = newValue }
    }

    private var script = AnnouncementScript()

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
        guard let announcement = script.announcement(for: event) else { return }
        if let text = announcement.text {
            speak(text, interrupting: announcement.interrupting)
        }
        if let haptic = announcement.haptic {
            play(haptic)
        }
    }

    private func play(_ haptic: AnnouncementHaptic) {
        switch haptic {
        case .runStart:
            heavyImpact.impactOccurred()
            Task { [heavyImpact] in
                try? await Task.sleep(for: .milliseconds(250))
                heavyImpact.impactOccurred()
            }
        case .restStart:
            heavyImpact.impactOccurred(intensity: 1.0)
        case .warning:
            heavyImpact.impactOccurred()
        case .light:
            lightImpact.impactOccurred()
        case .countdown:
            // 숫자는 음성으로 센다.
            break
        case .success:
            notification.notificationOccurred(.success)
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
