//
//  HealthRecorder.swift
//  SplitsWatch
//
//  HKWorkoutSession + HKLiveWorkoutBuilder. 손목을 내려도 앱이 계속 돌게 하고, 심박수를 모으고,
//  끝나면 건강 앱에 러닝으로 남긴다. 거리와 구간 판단은 하지 않는다. 그건 WorkoutEngine이 한다.
//

import CoreLocation
import Foundation
import HealthKit

final class HealthRecorder {
    /// 최근 심박수(bpm).
    var onHeartRate: ((Double) -> Void)?

    private let store = HKHealthStore()
    private let delegate = HealthSessionDelegate()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var collectionStart: Task<Void, Never>?
    private var hasEnded = false

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var shareTypes: Set<HKSampleType> {
        [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
        ]
    }

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
        ]
    }

    /// 이미 답한 권한이면 바로 돌아온다.
    func requestAuthorization() async {
        guard Self.isAvailable else { return }
        try? await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    /// 카운트다운 동안 부른다. 센서를 미리 깨운다.
    /// 실패하면 false. 세션은 그래도 돌지만 손목을 내리면 앱이 멈출 수 있다.
    func prepare() async -> Bool {
        guard Self.isAvailable else { return false }
        if session != nil { return true }
        await requestAuthorization()

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            session.delegate = delegate
            builder.delegate = delegate
            delegate.onHeartRate = { [weak self] bpm in
                self?.onHeartRate?(bpm)
            }
            session.prepare()
            self.session = session
            self.builder = builder
            return true
        } catch {
            return false
        }
    }

    func begin(at date: Date) {
        guard let session, let builder else { return }
        session.startActivity(with: date)
        collectionStart = Task {
            try? await builder.beginCollection(at: date)
        }
    }

    func pause() {
        session?.pause()
    }

    func resume() {
        session?.resume()
    }

    /// 세션을 끝낸다. 건강 앱에 남길지는 요약 화면에서 정한다. 두 번 불러도 된다.
    func end() {
        guard !hasEnded else { return }
        hasEnded = true
        session?.end()
    }

    /// 러닝 운동 + 경로. 경로는 엔진이 거리로 인정한 점만 쓴다. iPhone 저장과 같은 방식이다.
    /// 거리·심박·칼로리 샘플은 워치가 직접 잰 값이 들어간다.
    func save(_ summary: WorkoutSummary) async {
        guard let builder else { return }
        defer { reset() }
        end()
        await collectionStart?.value
        do {
            try await builder.endCollection(at: summary.endedAt)
            try await builder.addMetadata([HKMetadataKeyWorkoutBrandName: "Splits"])
            guard let workout = try await builder.finishWorkout() else { return }
            try await saveRoute(summary.route, for: workout)
        } catch {
            // 건강 앱 저장이 실패해도 기록은 iPhone으로 간다.
        }
    }

    func discard() {
        end()
        builder?.discardWorkout()
        reset()
    }

    private func saveRoute(_ route: [RoutePoint], for workout: HKWorkout) async throws {
        let locations = route.map { point in
            CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                altitude: 0,
                horizontalAccuracy: 10,
                verticalAccuracy: -1,
                timestamp: point.timestamp
            )
        }
        guard locations.count >= 2 else { return }

        let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: nil)
        try await routeBuilder.insertRouteData(locations)
        _ = try await routeBuilder.finishRoute(with: workout, metadata: nil)
    }

    private func reset() {
        session = nil
        builder = nil
        collectionStart = nil
    }
}

/// HealthKit 콜백은 백그라운드 큐에서 온다. 값만 꺼내 메인 액터로 넘긴다.
nonisolated final class HealthSessionDelegate: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, @unchecked Sendable {
    var onHeartRate: (@MainActor (Double) -> Void)?

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let heartRate = HKQuantityType(.heartRate)
        guard collectedTypes.contains(heartRate),
              let quantity = workoutBuilder.statistics(for: heartRate)?.mostRecentQuantity() else { return }
        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        Task { @MainActor in
            self.onHeartRate?(bpm)
        }
    }
}
