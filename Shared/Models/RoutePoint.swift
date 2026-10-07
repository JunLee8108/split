//
//  RoutePoint.swift
//  Splits
//

import Foundation

/// 경로의 한 점. 구조체 배열을 JSON으로 직렬화해 Workout.routeData에 저장한다.
nonisolated struct RoutePoint: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    /// 이 점이 속한 스텝의 index.
    var stepIndex: Int
}
