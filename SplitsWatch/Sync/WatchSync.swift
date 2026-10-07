//
//  WatchSync.swift
//  SplitsWatch
//
//  워치 쪽 연결. iPhone이 보낸 플랜·설정을 받아 두고, 저장한 세션을 iPhone으로 보낸다.
//  받은 내용은 저장해 두므로 iPhone 없이 나가도 목록이 뜬다.
//  보낼 세션은 outbox 폴더에 파일로 남겨 두고, 전송이 끝나야 지운다. iPhone이 멀리 있어도 다음 연결 때 간다.
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
        link.onStateChange = { [weak self] in
            self?.flushOutbox()
        }
        link.onFileSent = { [weak self] id, succeeded in
            self?.fileSent(id, succeeded: succeeded)
        }
        link.activate()
    }

    /// 저장한 세션을 iPhone 기록으로 보낸다.
    func send(_ summary: WorkoutSummary) {
        guard let data = try? SyncCoding.encode(summary), let outbox = Self.outbox else { return }
        let url = outbox.appendingPathComponent("\(UUID().uuidString).json")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
        if link.isActivated {
            link.transferWorkoutFile(url)
        }
        // 아직 활성화 전이면 활성화가 끝날 때 flushOutbox가 보낸다.
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

    // MARK: outbox

    private static var outbox: URL? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        let url = base.appendingPathComponent("outbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 보내는 중이 아닌 파일을 다시 보낸다. 앱이 꺼졌다 켜졌거나 지난 전송이 실패한 것들.
    private func flushOutbox() {
        guard link.isActivated, let outbox = Self.outbox,
              let files = try? FileManager.default.contentsOfDirectory(at: outbox, includingPropertiesForKeys: nil) else { return }
        let sending = link.outstandingFileIDs
        for file in files where file.pathExtension == "json" && !sending.contains(file.lastPathComponent) {
            link.transferWorkoutFile(file)
        }
    }

    private func fileSent(_ id: String, succeeded: Bool) {
        // 실패한 파일은 남겨 두고 다음 활성화 때 다시 보낸다.
        guard succeeded, let outbox = Self.outbox else { return }
        try? FileManager.default.removeItem(at: outbox.appendingPathComponent(id))
    }
}
