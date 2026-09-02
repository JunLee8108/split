//
//  WorkoutEngine.swift
//  Splits
//
//  세션의 상태 머신. UI·CoreLocation·타이머를 모른다.
//  시간은 tick(now:)로, 위치는 ingest(_:)로 받는다. 그래서 백그라운드에서도, 테스트에서도 같은 코드가 돈다.
//

import Foundation
import Observation

nonisolated enum WorkoutState: String, Sendable {
    case idle
    case running
    case paused
    case finished
}

nonisolated struct WorkoutSummary: Hashable, Sendable {
    var planName: String
    var startedAt: Date
    var endedAt: Date
    var totalDistance: Double
    var movingTime: TimeInterval
    var laps: [LapRecord]
    var route: [RoutePoint]

    var averagePace: TimeInterval? { PaceMath.pace(distance: totalDistance, duration: movingTime) }
}

nonisolated enum WorkoutEvent: Hashable, Sendable {
    /// 구간 하나가 끝났다. 다음 stepStarted 직전에 온다. 수동 종료로 잘린 마지막 랩에는 오지 않는다.
    case lapCompleted(LapRecord)
    /// 새 구간이 시작됐다. 세션 시작 시 첫 구간에도 온다.
    case stepStarted(WorkoutStep)
    /// 시간 목표 구간의 종료 몇 초 전. 5, 4, 3, 2, 1 순서로 한 번씩.
    case countdown(Int)
    /// 거리 목표 구간의 종료 직전. 남은 미터.
    case approaching(remainingMeters: Double)
    /// 누적 거리가 1km 단위를 넘었다. 그 1km에 걸린 페이스.
    case kilometer(Int, splitPace: TimeInterval?)
    case paused
    case resumed
    case finished(WorkoutSummary)
}

@Observable
final class WorkoutEngine {
    private(set) var state: WorkoutState = .idle
    private(set) var planName: String = ""
    private(set) var steps: [WorkoutStep] = []
    private(set) var currentIndex: Int = 0
    private(set) var tracker: SegmentTracker?
    /// 미터.
    private(set) var totalDistance: Double = 0
    /// 초. 일시정지 시간 제외.
    private(set) var movingTime: TimeInterval = 0
    /// 초/km. 최근 15초 이동 평균. 모르면 nil.
    private(set) var currentPace: TimeInterval?
    private(set) var laps: [LapRecord] = []
    private(set) var route: [RoutePoint] = []
    private(set) var startedAt: Date?
    private(set) var summary: WorkoutSummary?

    /// 구간 전환·카운트다운 등을 알린다. 음성·햅틱은 이 밖에서 붙인다.
    var onEvent: ((WorkoutEvent) -> Void)?

    /// 시간 목표 구간에서 카운트다운을 시작할 초. 설정에서 바꾼다.
    var countdownSeconds: Int = 5
    /// 거리 목표 구간에서 "곧 끝남"을 알릴 남은 거리(미터).
    var approachingDistance: Double = 100

    private var lastTick: Date?
    private var accumulator = DistanceAccumulator()
    private var paceCalculator = PaceCalculator()
    private var lastCountdownAnnounced: Int?
    private var approachingAnnounced = false
    private var kilometersAnnounced = 0
    private var movingTimeAtLastKilometer: TimeInterval = 0

    var currentStep: WorkoutStep? {
        steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
    }

    var nextStep: WorkoutStep? {
        let next = currentIndex + 1
        return steps.indices.contains(next) ? steps[next] : nil
    }

    var isActive: Bool { state == .running || state == .paused }

    // MARK: 제어

    func start(planName: String, steps: [WorkoutStep], at now: Date = .now) {
        guard !steps.isEmpty else { return }
        self.planName = planName
        self.steps = steps
        currentIndex = 0
        tracker = SegmentTracker(step: steps[0])
        totalDistance = 0
        movingTime = 0
        currentPace = nil
        laps = []
        route = []
        summary = nil
        startedAt = now
        lastTick = now
        accumulator = DistanceAccumulator()
        accumulator.start(at: now)
        paceCalculator = PaceCalculator()
        lastCountdownAnnounced = nil
        approachingAnnounced = false
        kilometersAnnounced = 0
        movingTimeAtLastKilometer = 0
        state = .running
        emit(.stepStarted(steps[0]))
    }

    func pause(at now: Date = .now) {
        guard state == .running else { return }
        tick(now: now)
        state = .paused
        currentPace = nil
        paceCalculator.reset()
        emit(.paused)
    }

    func resume(at now: Date = .now) {
        guard state == .paused else { return }
        lastTick = now
        state = .running
        emit(.resumed)
    }

    /// 현재 구간을 수동으로 끝내고 다음으로 넘어간다.
    func skipStep(at now: Date = .now) {
        guard state == .running || state == .paused else { return }
        if state == .running { tick(now: now) }
        advance(carriedDistance: 0, carriedTime: 0, at: now)
    }

    /// 세션을 끝내고 요약을 돌려준다. 자동 완료 뒤에 불러도 같은 요약을 준다.
    @discardableResult
    func finish(at now: Date = .now) -> WorkoutSummary? {
        if state == .finished { return summary }
        guard state == .running || state == .paused else { return nil }
        if state == .running { tick(now: now) }
        if let tracker, tracker.elapsed > 0 || tracker.distance > 0 {
            laps.append(tracker.lapRecord())
        }
        return complete(at: now)
    }

    // MARK: 입력

    /// 1초마다, 그리고 상태를 바꾸기 직전에 부른다. 벽시계 차이만큼 시간을 누적하므로
    /// 백그라운드에서 타이머가 늦게 와도 빠지는 시간이 없다.
    func tick(now: Date) {
        guard state == .running, let last = lastTick else { return }
        let delta = now.timeIntervalSince(last)
        lastTick = now
        guard delta > 0 else { return }

        movingTime += delta
        applyTime(delta, at: now)

        if paceCalculator.pace(at: now) == nil {
            currentPace = nil
        }
    }

    func ingest(_ sample: LocationSample) {
        switch state {
        case .paused:
            // 기준점만 옮긴다. 재개할 때 정지 중 움직인 거리가 튀어 들어오지 않게.
            _ = accumulator.ingest(sample, accumulate: false)
        case .running:
            let meters = accumulator.ingest(sample)
            guard meters > 0 else { return }
            applyDistance(meters, sample: sample)
        case .idle, .finished:
            return
        }
    }

    // MARK: 내부

    private func applyTime(_ delta: TimeInterval, at now: Date) {
        guard var tracker else { return }
        tracker.add(time: delta)
        self.tracker = tracker

        if tracker.isComplete {
            let overflow = tracker.overflow
            advance(carriedDistance: overflow.distance, carriedTime: overflow.time, at: now)
            return
        }

        if !tracker.step.target.isDistance {
            let remaining = Int(tracker.remaining.rounded(.up))
            if remaining <= countdownSeconds, remaining >= 1, lastCountdownAnnounced != remaining {
                lastCountdownAnnounced = remaining
                emit(.countdown(remaining))
            }
        }
    }

    private func applyDistance(_ meters: Double, sample: LocationSample) {
        totalDistance += meters
        route.append(RoutePoint(
            latitude: sample.latitude,
            longitude: sample.longitude,
            timestamp: sample.timestamp,
            stepIndex: currentIndex
        ))
        paceCalculator.record(cumulativeDistance: totalDistance, at: sample.timestamp)
        currentPace = paceCalculator.pace(at: sample.timestamp)

        let kilometers = Int(totalDistance / 1000)
        if kilometers > kilometersAnnounced {
            kilometersAnnounced = kilometers
            let splitTime = movingTime - movingTimeAtLastKilometer
            movingTimeAtLastKilometer = movingTime
            emit(.kilometer(kilometers, splitPace: PaceMath.pace(distance: 1000, duration: splitTime)))
        }

        guard var tracker else { return }
        tracker.add(distance: meters)
        self.tracker = tracker

        if tracker.isComplete {
            let overflow = tracker.overflow
            advance(carriedDistance: overflow.distance, carriedTime: overflow.time, at: sample.timestamp)
            return
        }

        if tracker.step.target.isDistance, !approachingAnnounced, tracker.remaining <= approachingDistance {
            approachingAnnounced = true
            emit(.approaching(remainingMeters: tracker.remaining))
        }
    }

    private func advance(carriedDistance: Double, carriedTime: TimeInterval, at now: Date) {
        if let tracker {
            let lap = tracker.lapRecord()
            laps.append(lap)
            emit(.lapCompleted(lap))
        }
        let next = currentIndex + 1
        guard steps.indices.contains(next) else {
            complete(at: now)
            return
        }
        currentIndex = next
        tracker = SegmentTracker(step: steps[next], carriedDistance: carriedDistance, carriedTime: carriedTime)
        lastCountdownAnnounced = nil
        approachingAnnounced = false
        emit(.stepStarted(steps[next]))
    }

    @discardableResult
    private func complete(at now: Date) -> WorkoutSummary {
        let result = WorkoutSummary(
            planName: planName,
            startedAt: startedAt ?? now,
            endedAt: now,
            totalDistance: totalDistance,
            movingTime: movingTime,
            laps: laps,
            route: route
        )
        summary = result
        tracker = nil
        currentPace = nil
        state = .finished
        emit(.finished(result))
        return result
    }

    private func emit(_ event: WorkoutEvent) {
        onEvent?(event)
    }
}
