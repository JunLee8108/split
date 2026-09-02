//
//  HealthKitService.swift
//  Splits
//
//  완료된 세션을 Apple 건강에 러닝 워크아웃으로 저장한다. 읽기는 하지 않는다.
//

import CoreLocation
import Foundation
import HealthKit

final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var shareTypes: Set<HKSampleType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.distanceWalkingRunning),
            HKSeriesType.workoutRoute(),
        ]
    }

    /// 설정에서 토글을 켤 때 부른다.
    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: shareTypes, read: [])
    }

    var isAuthorized: Bool {
        isAvailable && store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    /// 러닝 워크아웃 + 거리 샘플 + 경로. 권한이 없으면 조용히 건너뛴다.
    func save(_ summary: WorkoutSummary) async throws {
        guard isAuthorized, summary.endedAt > summary.startedAt else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: summary.startedAt)

        if summary.totalDistance > 0 {
            let sample = HKQuantitySample(
                type: HKQuantityType(.distanceWalkingRunning),
                quantity: HKQuantity(unit: .meter(), doubleValue: summary.totalDistance),
                start: summary.startedAt,
                end: summary.endedAt
            )
            try await builder.addSamples([sample])
        }

        try await builder.addMetadata([
            HKMetadataKeyIndoorWorkout: false,
            HKMetadataKeyWorkoutBrandName: "Splits",
        ])
        try await builder.endCollection(at: summary.endedAt)
        guard let workout = try await builder.finishWorkout() else { return }

        let locations = summary.route.map { point in
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
}
