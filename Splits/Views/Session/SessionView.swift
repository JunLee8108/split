//
//  SessionView.swift
//  Splits
//
//  달리는 동안 보는 유일한 화면. 숫자 하나가 지배하고, 배경색이 구간 종류를 말한다.
//  항상 어두운 배경을 쓴다. 햇빛 아래에서는 흰 배경보다 대비가 높다.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

struct SessionView: View {
    let plan: IntervalPlan

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue

    @State private var session = WorkoutSession()
    @State private var summary: WorkoutSummary?
    @State private var showSummary = false

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }
    private var engine: WorkoutEngine { session.engine }
    private var kind: StepKind { engine.currentStep?.kind ?? engine.laps.last?.kind ?? .run }

    var body: some View {
        ZStack(alignment: .top) {
            SessionBackground(kind: kind)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    session.skipStep()
                }

            VStack(spacing: 0) {
                // 컨트롤을 뺀 나머지 전체가 두 번 탭 영역이다. 여백까지 포함.
                VStack(spacing: 0) {
                    SessionHeader(engine: engine, kind: kind, unit: unit)
                        .padding(.top, 8)

                    Spacer(minLength: 12)

                    SessionMetrics(engine: engine, unit: unit)

                    Spacer(minLength: 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    session.skipStep()
                }

                SessionControls(session: session, tint: kind.tint, onFinish: endSession)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            if session.location.isAuthorizationDenied {
                permissionBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if engine.state == .idle {
                session.start(plan: plan)
            }
        }
        .onChange(of: engine.state) { _, newState in
            // 마지막 구간이 스스로 끝난 경우.
            if newState == .finished, summary == nil {
                summary = session.end()
                showSummary = summary != nil
            }
        }
        .sheet(isPresented: $showSummary) {
            if let summary {
                SessionSummaryView(
                    summary: summary,
                    unit: unit,
                    onSave: {
                        Workout.save(summary, into: modelContext)
                        dismiss()
                    },
                    onDiscard: {
                        dismiss()
                    }
                )
                .interactiveDismissDisabled()
            }
        }
    }

    private func endSession() {
        guard summary == nil else { return }
        summary = session.end()
        if summary != nil {
            showSummary = true
        } else {
            dismiss()
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
            Text("위치 권한이 꺼져 있어 거리를 잴 수 없어요.")
                .font(.footnote)
            Spacer()
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// 어두운 바탕 위에 구간 색을 옅게 얹는다. 구간이 바뀌면 색이 부드럽게 넘어간다.
struct SessionBackground: View {
    let kind: StepKind

    static let base = Color(red: 16 / 255, green: 18 / 255, blue: 21 / 255)

    var body: some View {
        ZStack {
            Self.base
            kind.tint.opacity(0.20)
            Circle()
                .fill(kind.tint.opacity(0.12))
                .frame(width: 360, height: 360)
                .offset(x: 150, y: -260)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: kind)
    }
}

struct SessionHeader: View {
    let engine: WorkoutEngine
    let kind: StepKind
    let unit: DistanceUnit

    var body: some View {
        VStack(spacing: 10) {
            ProgressBar(progress: engine.tracker?.progress ?? 1, tint: kind.tint)

            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(kind.tint)
                        .frame(width: 8, height: 8)
                    Text(stepLabel)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(kind.tint)
                }
                Spacer()
                Text(Formatters.clock(engine.movingTime))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("경과 \(Formatters.spokenDuration(engine.movingTime))")
            }

            HStack {
                Text(nextLabel)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
    }

    private var stepLabel: String {
        guard let step = engine.currentStep else { return "완료" }
        return "\(step.kind.badge) \(step.ordinal) / \(step.ordinalTotal)"
    }

    private var nextLabel: String {
        guard engine.currentStep != nil else { return " " }
        guard let next = engine.nextStep else { return "마지막 구간" }
        return "다음: \(next.kind.badge) \(Formatters.target(next.target, unit: unit))"
    }
}

struct ProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule()
                    .fill(tint)
                    .frame(width: max(proxy.size.width * min(max(progress, 0), 1), 6))
            }
        }
        .frame(height: 5)
        .animation(.linear(duration: 0.3), value: progress)
        .accessibilityHidden(true)
    }
}

/// 한 화면, 한 숫자. 현재 구간에서 남은 것만 크게 보여 준다.
struct SessionMetrics: View {
    let engine: WorkoutEngine
    let unit: DistanceUnit

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 4) {
                Text(primary.value)
                    .font(.system(size: 104, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Text(primary.caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)

            HStack(alignment: .top, spacing: 0) {
                Stat(value: Formatters.pace(engine.currentPace, unit: unit), label: "현재 페이스")
                Stat(value: distance.value, label: distance.unit)
                Stat(value: Formatters.clock(engine.tracker?.elapsed ?? 0), label: "이번 구간")
            }
        }
    }

    private var distance: (value: String, unit: String) {
        Formatters.distanceValue(engine.totalDistance, unit: unit)
    }

    private var primary: (value: String, caption: String) {
        guard let tracker = engine.tracker else {
            return ("완료", " ")
        }
        switch tracker.step.target {
        case .distance(let target):
            let remaining = Formatters.distanceValue(tracker.remaining, unit: unit)
            return (remaining.value, "\(remaining.unit) 남음 · 목표 \(Formatters.distance(target, unit: unit))")
        case .duration(let target):
            return (Formatters.clock(tracker.remaining.rounded(.up)), "남음 · 목표 \(Formatters.clock(target))")
        }
    }

    private var accessibilityText: String {
        guard let tracker = engine.tracker else { return "세션 완료" }
        let step = tracker.step
        let remaining: String
        switch step.target {
        case .distance: remaining = Formatters.spokenDistance(tracker.remaining.rounded(), unit: unit)
        case .duration: remaining = Formatters.spokenDuration(tracker.remaining)
        }
        return "\(step.kind.koreanName) \(step.ordinal), \(remaining) 남음"
    }

    private struct Stat: View {
        let value: String
        let label: String

        var body: some View {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold))
                    .monospacedDigit()
                Text(label)
                    .font(.caption2.weight(.medium))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}
