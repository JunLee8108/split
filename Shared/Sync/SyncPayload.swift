//
//  SyncPayload.swift
//  Splits
//
//  iPhone과 워치가 WatchConnectivity로 주고받는 값. JSON 하나로 묶어 payload 키에 담는다.
//

import Foundation

/// iPhone → 워치. applicationContext로 보낸다. 늘 최신 하나만 의미가 있고,
/// 워치 앱이 꺼져 있어도 다음에 켜질 때 받는다.
nonisolated struct WatchContext: Hashable, Codable, Sendable {
    /// iPhone 목록과 같은 순서(만든 순).
    var plans: [PlanBlueprint]
    /// 마지막으로 뛴 플랜. 워치 목록 맨 위에 둔다.
    var lastPlanName: String
    var settings: SessionSettings
}

nonisolated enum SyncCoding {
    static let payloadKey = "payload"
    /// 파일 메타데이터에서 무엇을 보냈는지.
    static let kindKey = "kind"
    /// 워치 → iPhone. 저장한 WorkoutSummary 하나. 경로가 길면 수백 KB라 파일로 보낸다.
    static let workoutKind = "workout"

    /// 키 순서를 고정한다. 같은 내용이면 같은 바이트가 나와 중복 전송을 거를 수 있다.
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
