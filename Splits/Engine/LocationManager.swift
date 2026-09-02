//
//  LocationManager.swift
//  Splits
//
//  CoreLocation 래퍼. iOS 17의 CLLocationUpdate.liveUpdates()를 쓰고,
//  CLBackgroundActivitySession으로 화면이 꺼져도 업데이트를 이어받는다.
//  거리 계산은 하지 않는다. 점을 LocationSample로 바꿔 넘길 뿐이다.
//

import CoreLocation
import Foundation
import Observation

@Observable
final class LocationManager {
    private(set) var isTracking = false
    private(set) var isAuthorizationDenied = false
    private(set) var isLocationUnavailable = false
    private(set) var latestSample: LocationSample?

    var onSample: ((LocationSample) -> Void)?

    private var updatesTask: Task<Void, Never>?
    private var backgroundSession: CLBackgroundActivitySession?

    func start() {
        guard !isTracking else { return }
        isTracking = true
        isAuthorizationDenied = false
        isLocationUnavailable = false

        // 포그라운드에서 만들어 두면 백그라운드로 가도 위치 업데이트가 유지된다.
        backgroundSession = CLBackgroundActivitySession()

        updatesTask = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.fitness) {
                    guard let self, !Task.isCancelled else { break }
                    self.handle(update)
                }
            } catch {
                self?.isLocationUnavailable = true
            }
        }
    }

    func stop() {
        updatesTask?.cancel()
        updatesTask = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
        isTracking = false
    }

    private func handle(_ update: CLLocationUpdate) {
        isAuthorizationDenied = update.authorizationDenied || update.authorizationDeniedGlobally
        isLocationUnavailable = update.locationUnavailable

        guard let location = update.location else { return }
        let sample = LocationSample(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy,
            speed: location.speed,
            isStationary: update.isStationary
        )
        latestSample = sample
        onSample?(sample)
    }
}
