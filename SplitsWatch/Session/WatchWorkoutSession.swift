//
//  WatchWorkoutSession.swift
//  SplitsWatch
//
//  엔진, 위치, 건강 세션, 안내를 한데 묶는다. iPhone의 WorkoutSession과 같은 자리다.
//  엔진과 위치 코드는 iPhone과 같은 것을 쓴다.
//

import Foundation
import Observation

@Observable
final class WatchWorkoutSession {
    let engine = WorkoutEngine()
    let location = LocationManager()
    /// 최근 심박수(bpm). 모르면 nil.
    private(set) var heartRate: Double?
    /// 건강 세션을 열지 못했다. 손목을 내리면 앱이 멈출 수 있다.
    private(set) var isBackgroundUnavailable = false

    @ObservationIgnored private let recorder = HealthRecorder()
    @ObservationIgnored private let announcer = WatchAnnouncer()
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    init() {
        engine.onEvent = { [weak self] event in
            self?.handle(event)
        }
        location.onSample = { [weak self] sample in
            self?.engine.ingest(sample)
        }
        recorder.onHeartRate = { [weak self] bpm in
            self?.heartRate = bpm
        }
    }

    /// 카운트다운 동안. GPS와 심박 센서를 미리 깨운다. 엔진이 시작 전이라 들어온 점은 버려진다.
    func prepare() async {
        location.start()
        isBackgroundUnavailable = !(await recorder.prepare())
    }

    /// 한 세션에 한 번만. 끝난 엔진을 다시 시작하지 않는다.
    func start(blueprint: PlanBlueprint) {
        guard engine.state == .idle else { return }

        let settings = AppSettings.session
        announcer.isVoiceEnabled = settings.voiceEnabled
        announcer.unit = settings.unit
        engine.countdownSeconds = settings.countdownSeconds
        engine.announcesTimeMilestones = settings.timeMilestonesEnabled

        let now = Date.now
        announcer.activateAudioSession()
        location.start()
        recorder.begin(at: now)
        engine.start(planName: blueprint.name, steps: blueprint.steps(), at: now)
        startTicking()
    }

    func pause() {
        engine.pause()
        recorder.pause()
    }

    func resume() {
        engine.resume()
        recorder.resume()
    }

    func skipStep() {
        engine.skipStep()
    }

    /// 세션을 끝내고 추적을 멈춘다. 저장 여부는 요약 화면이 정한다.
    /// 마지막 구간이 자동으로 끝난 뒤에 불러도 같은 요약을 준다.
    @discardableResult
    func end() -> WorkoutSummary? {
        let summary = engine.finish()
        teardown()
        return summary
    }

    /// 요약 화면에서 저장. iPhone 기록으로 보내고, 건강 앱에는 설정이 켜져 있을 때만 남긴다.
    func save(_ summary: WorkoutSummary) async {
        WatchSync.shared.send(summary)
        if AppSettings.saveToHealth {
            await recorder.save(summary)
        } else {
            recorder.discard()
        }
    }

    func discard() {
        recorder.discard()
    }

    private func handle(_ event: WorkoutEvent) {
        announcer.handle(event)
        if case .finished = event {
            // 마지막 구간이 자동으로 끝난 경우. 추적은 멈추되 저장은 화면이 결정한다.
            stopTicking()
            location.stop()
            recorder.end()
        }
    }

    /// 초당 4번. 경과 시간은 벽시계로 재므로 틱 간격은 표시 부드러움만 정한다.
    private static let tickInterval: Duration = .milliseconds(250)

    private func startTicking() {
        stopTicking()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tickInterval, tolerance: .zero)
                guard let self, !Task.isCancelled else { break }
                self.engine.tick(now: .now)
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func teardown() {
        stopTicking()
        location.stop()
        recorder.end()
        announcer.deactivateAudioSession()
    }
}
