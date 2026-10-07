//
//  PhoneSync.swift
//  Splits
//
//  iPhone 쪽 워치 연결. 플랜과 설정이 바뀌면 워치로 보내고, 워치에서 저장한 세션을 기록에 넣는다.
//  워치가 보낸 파일이 오면 시스템이 앱을 백그라운드로 깨운다. 그래서 화면이 아니라 앱 init에서 시작한다.
//

import Foundation
import SwiftData

final class PhoneSync {
    static let shared = PhoneSync()

    private let link = SessionLink()
    private var container: ModelContainer?
    private var observers: [NSObjectProtocol] = []
    private var pushTask: Task<Void, Never>?
    /// 같은 내용을 다시 보내지 않는다.
    private var lastSent: Data?

    func start(container: ModelContainer) {
        guard self.container == nil else { return }
        self.container = container

        link.onStateChange = { [weak self] in
            self?.schedulePush()
        }
        link.onWorkoutFile = { [weak self] data in
            self?.importWorkout(data)
        }
        link.activate()

        // 플랜 편집은 저장될 때, 설정과 마지막 플랜은 UserDefaults가 바뀔 때 알 수 있다.
        let center = NotificationCenter.default
        observers = [ModelContext.didSave, UserDefaults.didChangeNotification].map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.schedulePush()
                }
            }
        }
    }

    /// 짧은 시간에 여러 번 바뀌어도 한 번만 보낸다.
    func schedulePush() {
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.push()
        }
    }

    private func push() {
        guard let container, link.isWatchAppInstalled else { return }
        let descriptor = FetchDescriptor<IntervalPlan>(sortBy: [SortDescriptor(\.createdAt)])
        let plans = (try? container.mainContext.fetch(descriptor)) ?? []
        let context = WatchContext(
            plans: plans.map(\.blueprint),
            lastPlanName: UserDefaults.standard.string(forKey: AppSettings.lastPlanNameKey) ?? "",
            settings: AppSettings.session
        )
        guard let data = try? SyncCoding.encode(context), data != lastSent else { return }
        do {
            try link.updateContext(data)
            lastSent = data
        } catch {
            // 다음 변경이나 다음 실행 때 다시 보낸다.
        }
    }

    /// 워치에서 저장한 세션. 건강 앱에는 워치가 이미 남겼으므로 여기서는 기록에만 넣는다.
    /// 같은 시각에 시작한 기록이 있으면 같은 세션이 두 번 온 것으로 보고 건너뛴다.
    private func importWorkout(_ data: Data) {
        guard let container, let summary = try? SyncCoding.decode(WorkoutSummary.self, from: data) else { return }
        let context = container.mainContext
        let startedAt = summary.startedAt
        let sameStart = FetchDescriptor<Workout>(predicate: #Predicate { $0.startedAt == startedAt })
        guard (try? context.fetchCount(sameStart)) == 0 else { return }

        let workout = Workout.save(summary, into: context)
        workout.source = Workout.watchSource
        try? context.save()
        // 워치에서 고른 플랜이 양쪽 모두 맨 위로 온다. 바뀐 값은 다음 push로 워치에도 간다.
        UserDefaults.standard.set(summary.planName, forKey: AppSettings.lastPlanNameKey)
    }
}
