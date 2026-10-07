//
//  WatchAnnouncer.swift
//  SplitsWatch
//
//  AnnouncementScript가 정한 문장과 진동을 워치에서 낸다.
//  워치는 손목 진동이 주 신호다. 음성은 에어팟이 연결돼 있을 때 가장 잘 들린다.
//

import AVFoundation
import Foundation
import WatchKit

final class WatchAnnouncer {
    var isVoiceEnabled = true
    var unit: DistanceUnit {
        get { script.unit }
        set { script.unit = newValue }
    }

    private var script = AnnouncementScript()
    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "ko-KR")

    /// 세션 시작 때 한 번. 음악 위에 안내가 얹히도록 duckOthers.
    func activateAudioSession() {
        guard isVoiceEnabled else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
        try? session.setActive(true)
    }

    /// 말하던 안내가 끝난 뒤에 내린다. 최대 10초까지만 기다린다.
    func deactivateAudioSession() {
        guard isVoiceEnabled else { return }
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
        if let haptic = announcement.haptic {
            play(haptic)
        }
        if let text = announcement.text {
            speak(text, interrupting: announcement.interrupting)
        }
    }

    private func play(_ haptic: AnnouncementHaptic) {
        let device = WKInterfaceDevice.current()
        switch haptic {
        case .runStart:
            device.play(.start)
        case .restStart:
            device.play(.stop)
        case .warning:
            device.play(.failure)
        case .light:
            device.play(.notification)
        case .countdown:
            // 화면을 안 봐도 끝나 가는 걸 알 수 있게 초마다 짧게.
            device.play(.click)
        case .success:
            device.play(.success)
        }
    }

    private func speak(_ text: String, interrupting: Bool) {
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
