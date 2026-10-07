//
//  WatchSync.swift
//  SplitsWatch
//
//  워치 쪽 연결. iPhone이 보낸 플랜·설정을 받아 둔다.
//  받은 내용은 저장해 두므로 iPhone 없이 나가도 목록이 뜬다.
//

import Foundation
import Observation

@Observable
final class WatchSync {
    static let shared = WatchSync()

    private(set) var plans: [PlanBlueprint] = []
    private(set) var lastPlanName = ""
    /// iPhone에서 한 번이라도 받았는지. 빈 목록 안내 문구를 고른다.
    private(set) var hasReceivedContext = false

    @ObservationIgnored private let link = SessionLink()

    private static let contextKey = "sync.watchContext"

    func start() {
        lastPlanName = UserDefaults.standard.string(forKey: AppSettings.lastPlanNameKey) ?? ""
        if let stored = UserDefaults.standard.data(forKey: Self.contextKey),
           let context = try? SyncCoding.decode(WatchContext.self, from: stored) {
            plans = context.plans
            hasReceivedContext = true
        }
        link.onContext = { [weak self] data in
            self?.receive(data)
        }
        link.activate()
    }

    /// 워치에서 플랜을 시작하면 바로 맨 위로 올린다. iPhone은 세션을 받으면 같은 이름으로 맞춘다.
    func markStarted(_ planName: String) {
        lastPlanName = planName
        UserDefaults.standard.set(planName, forKey: AppSettings.lastPlanNameKey)
    }

    /// 활성화될 때마다 마지막으로 받은 것이 다시 온다. 이미 반영한 것이면 건너뛴다.
    /// 그래야 워치에서 고른 마지막 플랜이 옛 값으로 되돌아가지 않는다.
    private func receive(_ data: Data) {
        guard data != UserDefaults.standard.data(forKey: Self.contextKey),
              let context = try? SyncCoding.decode(WatchContext.self, from: data) else { return }
        plans = context.plans
        hasReceivedContext = true
        // 세션 코드는 AppSettings를 읽는다. 같은 키로 써 두면 iPhone과 같은 설정으로 돈다.
        AppSettings.store(context.settings)
        if !context.lastPlanName.isEmpty {
            markStarted(context.lastPlanName)
        }
        UserDefaults.standard.set(data, forKey: Self.contextKey)
    }
}
