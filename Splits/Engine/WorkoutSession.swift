//
//  WorkoutSession.swift
//  Splits
//
//  엔진, 위치, 음성, 타이머를 한데 묶는다. 화면은 이 객체 하나만 본다.
//

import Foundation
import Observation
import SwiftData
import UIKit

@Observable
final class WorkoutSession {
    let engine = WorkoutEngine()
    let location = LocationManager()
    let announcer = Announcer()

    private var tickTask: Task<Void, Never>?

    var state: WorkoutState { engine.state }

    init() {
        engine.onEvent = { [weak self] event in
            self?.handle(event)
        }
        location.onSample = { [weak self] sample in
            self?.engine.ingest(sample)
        }
    }

    func start(plan: IntervalPlan) {
        start(blueprint: plan.blueprint)
    }

    func start(blueprint: PlanBlueprint) {
        guard !engine.isActive else { return }

        announcer.isVoiceEnabled = AppSettings.voiceEnabled
        announcer.unit = AppSettings.distanceUnit
        engine.countdownSeconds = AppSettings.countdownSeconds

        announcer.activateAudioSession()
        location.start()
        engine.start(planName: blueprint.name, steps: blueprint.steps())
        startTicking()
        UIApplication.shared.isIdleTimerDisabled = AppSettings.keepScreenOn
    }

    func pause() {
        engine.pause()
    }

    func resume() {
        engine.resume()
    }

    func skipStep() {
        engine.skipStep()
    }

    /// 세션을 끝내고 결과를 저장한다. 저장한 Workout을 돌려준다.
    @discardableResult
    func finish(saveInto context: ModelContext?) -> Workout? {
        guard let summary = engine.finish() else {
            teardown()
            return nil
        }
        teardown()
        guard let context else { return nil }
        return Workout.save(summary, into: context)
    }

    /// 저장하지 않고 버린다.
    func discard() {
        _ = engine.finish()
        teardown()
    }

    private func handle(_ event: WorkoutEvent) {
        announcer.handle(event)
        if case .finished = event {
            // 마지막 구간이 자동으로 끝난 경우. 추적은 멈추되 저장은 화면이 결정한다.
            stopTicking()
            location.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func startTicking() {
        stopTicking()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
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
        announcer.deactivateAudioSession()
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
