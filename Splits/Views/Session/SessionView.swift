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
                        if AppSettings.saveToHealth {
                            Task {
                                try? await HealthKitService.shared.save(summary)
                            }
                        }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let base = Color(red: 16 / 255, green: 18 / 255, blue: 21 / 255)

    var body: some View {
        ZStack {
            Self.base
            kind.tint.opacity(0.20)
            Circle()
                .fill(kind.tint.opacity(0.12))
                .frame(width: 360, height: 360)
                .offset(x: 150, y: -260)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: kind)
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

/// 위에서 아래로 "남은 것 → 이번 구간에서 한 것 → 세션 전체" 세 층. 급할수록 위만 본다.
struct SessionMetrics: View {
    let engine: WorkoutEngine
    let unit: DistanceUnit
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var tracker: SegmentTracker? { engine.tracker }
    private var tint: Color { (tracker?.step.kind ?? .run).tint }

    var body: some View {
        VStack(spacing: 26) {
            // 1층: 이 구간을 끝내는 값
            BigValue(text: primary.value, label: primary.label, size: 92, style: HierarchicalShapeStyle.primary)

            // 2층: 목표까지, 없으면 구간 경과
            BigValue(text: secondary.value, label: secondary.label, size: 52, style: tint)

            // 3층: 이번 구간에서 한 것
            Divider().overlay(.white.opacity(0.15))
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 14) { segmentStats }
                VStack(spacing: 14) { sessionStats }
            } else {
                HStack(alignment: .top, spacing: 0) { segmentStats }
                HStack(alignment: .top, spacing: 0) { sessionStats }
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: 1층

    private var primary: (value: String, label: String) {
        guard let tracker else { return ("완료", " ") }
        switch tracker.step.target {
        case .distance:
            return (Formatters.distance(tracker.remaining.rounded(), unit: unit), "남은 거리")
        case .duration:
            return (Formatters.clock(tracker.remaining.rounded(.up)), "남은 시간")
        }
    }

    // MARK: 2층

    private var secondary: (value: String, label: String) {
        guard let tracker else { return (" ", " ") }
        let step = tracker.step
        if let goal = step.goalValue {
            let pace = Formatters.pace(step.goalPace, unit: unit)
            switch step.target {
            case .distance:
                let remaining = goal - tracker.elapsed
                if remaining >= 0 {
                    return (Formatters.clock(remaining.rounded(.up)), "목표까지 · \(pace)")
                }
                return ("+\(Formatters.clock(-remaining))", "목표 초과 · \(pace)")
            case .duration:
                let remaining = goal - tracker.distance
                if remaining >= 0 {
                    return (Formatters.distance(remaining.rounded(), unit: unit), "목표까지 · \(pace)")
                }
                return ("+\(Formatters.distance(-remaining, unit: unit))", "목표 초과 · \(pace)")
            }
        }
        // 목표가 없으면 1층과 반대 축을 보여 준다. 거리 구간이면 경과 시간, 시간 구간이면 달린 거리.
        switch step.target {
        case .distance:
            return (Formatters.clock(tracker.elapsed), "구간 경과")
        case .duration:
            return (Formatters.distance(tracker.distance, unit: unit), "구간 거리")
        }
    }

    // MARK: 3층

    @ViewBuilder
    private var segmentStats: some View {
        Stat(value: Formatters.distance(tracker?.distance ?? 0, unit: unit), label: "이번 구간 거리")
        Stat(value: Formatters.clock(tracker?.elapsed ?? 0), label: "이번 구간 시간")
    }

    @ViewBuilder
    private var sessionStats: some View {
        Stat(value: Formatters.pace(engine.currentPace, unit: unit), label: "페이스")
        Stat(value: Formatters.distance(engine.totalDistance, unit: unit), label: "총 거리")
        Stat(value: Formatters.clock(engine.movingTime), label: "총 시간")
    }

    // MARK: 부품

    private struct BigValue: View {
        let text: String
        let label: String
        let size: CGFloat
        let style: AnyShapeStyle

        init(text: String, label: String, size: CGFloat, style: some ShapeStyle) {
            self.text = text
            self.label = label
            self.size = size
            self.style = AnyShapeStyle(style)
        }

        var body: some View {
            VStack(spacing: 2) {
                Text(text)
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(style)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private struct Stat: View {
        let value: String
        let label: String

        var body: some View {
            VStack(spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}
