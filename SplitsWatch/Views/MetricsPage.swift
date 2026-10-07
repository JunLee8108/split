//
//  MetricsPage.swift
//  SplitsWatch
//
//  iPhone 세션 화면을 손목 크기로 줄인 것. 위에서 아래로 "남은 것 → 목표 → 지금 상태".
//  배경색이 구간 종류를 말한다. 손목을 내린 상시 표시에서는 색을 빼고 숫자만 남긴다.
//

import SwiftUI

struct MetricsPage: View {
    let session: WatchWorkoutSession
    let unit: DistanceUnit

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var engine: WorkoutEngine { session.engine }
    private var tracker: SegmentTracker? { engine.tracker }
    private var kind: StepKind { engine.currentStep?.kind ?? engine.laps.last?.kind ?? .run }

    var body: some View {
        let primary = SessionReadout.primary(tracker, unit: unit)
        let secondary = SessionReadout.secondary(tracker, unit: unit)

        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 4)

            if !isLuminanceReduced {
                ProgressCapsule(progress: tracker?.progress ?? 1, tint: kind.tint)
                    .padding(.bottom, 2)
            }

            Text(primary.value)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(primary.label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(secondary.value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(isLuminanceReduced ? Color.secondary : kind.tint)
                .padding(.top, 2)
            Text(secondary.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Stat(value: Formatters.pace(engine.currentPace, unit: unit), label: "페이스")
                Stat(value: heartRateText, label: "심박")
                Stat(value: Formatters.distance(engine.totalDistance, unit: unit), label: "총 거리")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 4)
        .background {
            ZStack {
                Color.black
                if !isLuminanceReduced {
                    kind.tint.opacity(0.22)
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: kind)
        }
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            if session.location.isAuthorizationDenied {
                Label("위치 꺼짐", systemImage: "location.slash.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
            } else {
                Text(stepLabel)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(kind.tint)
            }
            Spacer(minLength: 4)
            Text(Formatters.clock(engine.movingTime))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var stepLabel: String {
        guard let step = engine.currentStep else { return "완료" }
        if engine.state == .paused {
            return "일시정지"
        }
        return "\(step.kind.badge) \(step.ordinal)/\(step.ordinalTotal)"
    }

    private var heartRateText: String {
        guard let bpm = session.heartRate else { return "—" }
        return "\(Int(bpm.rounded()))"
    }

    private struct Stat: View {
        let value: String
        let label: String

        var body: some View {
            VStack(spacing: 0) {
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ProgressCapsule: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule()
                    .fill(tint)
                    .frame(width: max(proxy.size.width * min(max(progress, 0), 1), 4))
            }
        }
        .frame(height: 4)
        .animation(.linear(duration: 0.3), value: progress)
        .accessibilityHidden(true)
    }
}
