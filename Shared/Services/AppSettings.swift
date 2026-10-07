//
//  AppSettings.swift
//  Splits
//
//  UserDefaults 키와 기본값. 뷰에서는 @AppStorage로, 엔진 쪽에서는 read()로 읽는다.
//

import Foundation

nonisolated enum DistanceUnit: String, CaseIterable, Sendable, Codable {
    case metric
    case imperial

    var label: String {
        switch self {
        case .metric: "킬로미터"
        case .imperial: "마일"
        }
    }
}

enum AppSettings {
    static let distanceUnitKey = "settings.distanceUnit"
    static let voiceEnabledKey = "settings.voiceEnabled"
    static let countdownSecondsKey = "settings.countdownSeconds"
    static let keepScreenOnKey = "settings.keepScreenOn"
    static let saveToHealthKey = "settings.saveToHealth"
    static let timeMilestonesKey = "settings.timeMilestones"
    static let lastPlanNameKey = "state.lastPlanName"

    static let defaultCountdownSeconds = 5

    static var distanceUnit: DistanceUnit {
        DistanceUnit(rawValue: UserDefaults.standard.string(forKey: distanceUnitKey) ?? "") ?? .metric
    }

    static var voiceEnabled: Bool {
        UserDefaults.standard.object(forKey: voiceEnabledKey) as? Bool ?? true
    }

    static var countdownSeconds: Int {
        let stored = UserDefaults.standard.integer(forKey: countdownSecondsKey)
        return stored == 0 ? defaultCountdownSeconds : stored
    }

    static var keepScreenOn: Bool {
        UserDefaults.standard.object(forKey: keepScreenOnKey) as? Bool ?? true
    }

    static var timeMilestonesEnabled: Bool {
        UserDefaults.standard.object(forKey: timeMilestonesKey) as? Bool ?? true
    }

    static var saveToHealth: Bool {
        UserDefaults.standard.bool(forKey: saveToHealthKey)
    }
}

/// 세션 동작에 필요한 설정 묶음. iPhone이 워치로 보내고, 워치는 받은 값을 자기 UserDefaults에 같은 키로 쓴다.
/// 그래서 워치에서도 AppSettings를 그대로 읽는다.
nonisolated struct SessionSettings: Hashable, Codable, Sendable {
    var unit: DistanceUnit
    var voiceEnabled: Bool
    var countdownSeconds: Int
    var timeMilestonesEnabled: Bool
    var saveToHealth: Bool
}

extension AppSettings {
    static var session: SessionSettings {
        SessionSettings(
            unit: distanceUnit,
            voiceEnabled: voiceEnabled,
            countdownSeconds: countdownSeconds,
            timeMilestonesEnabled: timeMilestonesEnabled,
            saveToHealth: saveToHealth
        )
    }

    static func store(_ settings: SessionSettings) {
        let defaults = UserDefaults.standard
        defaults.set(settings.unit.rawValue, forKey: distanceUnitKey)
        defaults.set(settings.voiceEnabled, forKey: voiceEnabledKey)
        defaults.set(settings.countdownSeconds, forKey: countdownSecondsKey)
        defaults.set(settings.timeMilestonesEnabled, forKey: timeMilestonesKey)
        defaults.set(settings.saveToHealth, forKey: saveToHealthKey)
    }
}
