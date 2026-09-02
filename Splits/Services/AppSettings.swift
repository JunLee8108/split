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
