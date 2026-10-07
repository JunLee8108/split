//
//  SessionScreen.swift
//  SplitsWatch
//
//  카운트다운 → 세션(왼쪽 조작, 가운데 숫자) → 요약. 운동 앱과 같은 배치라 손이 익숙하다.
//

import SwiftUI
import WatchKit

struct SessionScreen: View {
    let blueprint: PlanBlueprint
    let onClose: () -> Void

    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var session = WatchWorkoutSession()
    @State private var countdown = 3
    @State private var page = SessionPage.metrics
    @State private var summary: WorkoutSummary?

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }
    private var engine: WorkoutEngine { session.engine }

    var body: some View {
        Group {
            if let summary {
                SummaryPage(
                    summary: summary,
                    unit: unit,
                    onSave: {
                        await session.save(summary)
                        onClose()
                    },
                    onDiscard: {
                        session.discard()
                        onClose()
                    }
                )
            } else if engine.state == .idle {
                CountdownView(value: countdown)
            } else {
                TabView(selection: $page) {
                    ControlsPage(
                        session: session,
                        onResume: { page = .metrics },
                        onEnd: endSession
                    )
                    .tag(SessionPage.controls)

                    MetricsPage(session: session, unit: unit)
                        .tag(SessionPage.metrics)
                }
                .tabViewStyle(.page(indexDisplayMode: isLuminanceReduced ? .never : .automatic))
            }
        }
        .task {
            await runCountdown()
        }
        .onChange(of: engine.state) { _, newState in
            // 마지막 구간이 스스로 끝난 경우.
            if newState == .finished, summary == nil {
                summary = session.end()
            }
        }
    }

    /// 3초 세는 동안 GPS와 심박 센서를 깨운다. 준비가 늦으면 끝날 때까지 기다린다.
    private func runCountdown() async {
        let preparing = Task { await session.prepare() }
        for value in stride(from: 3, through: 1, by: -1) {
            countdown = value
            WKInterfaceDevice.current().play(.click)
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
        }
        await preparing.value
        guard !Task.isCancelled else { return }
        session.start(blueprint: blueprint)
        WatchSync.shared.markStarted(blueprint.name)
    }

    private func endSession() {
        guard summary == nil else { return }
        summary = session.end()
        if summary == nil {
            onClose()
        }
    }
}

private enum SessionPage: Hashable {
    case controls
    case metrics
}

private struct CountdownView: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .font(.system(size: 80, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(StepKind.run.tint)
            .contentTransition(.numericText(countsDown: true))
            .animation(.snappy, value: value)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("\(value)초 뒤 시작")
    }
}
