//
//  IntroView.swift
//  Splits
//
//  콜드 스타트 직후 1.6초. 스톱워치가 올라가다 "스플릿"으로 끊기고, 그 자리에 SPLITS가 찍힌다.
//  런치 스크린은 정적이라 애니메이션은 여기서 한다. 탭하면 바로 건너뛴다.
//

import SwiftUI
import UIKit

struct IntroView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var didSplit = false
    @State private var finished = false

    // 타임라인(초)
    private static let splitAt: TimeInterval = 0.9
    private static let lettersFrom: TimeInterval = 1.05
    private static let letterGap: TimeInterval = 0.07
    private static let total: TimeInterval = 1.7
    /// 멈추는 순간의 스톱워치 값. 400m 목표 1:35 근처.
    private static let splitValue: TimeInterval = 94.7

    private let letters = Array("SPLITS")
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        ZStack {
            SessionBackground.base.ignoresSafeArea()

            if reduceMotion {
                wordmark(visibleLetters: letters.count, showDot: true)
                    .transition(.opacity)
            } else {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSince(start)
                    animated(at: t)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task {
            haptic.prepare()
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.9 : Self.total))
            finish()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Splits")
        .accessibilityHint("탭하면 건너뜁니다")
    }

    // MARK: 타임라인

    @ViewBuilder
    private func animated(at t: TimeInterval) -> some View {
        let split = t >= Self.splitAt
        let counter = split ? Self.splitValue : Self.splitValue * max(t, 0) / Self.splitAt
        let progress = min(max(t / Self.splitAt, 0), 1)
        let visible = split ? min(max(Int((t - Self.lettersFrom) / Self.letterGap) + 1, 0), letters.count) : 0

        VStack(spacing: 28) {
            Spacer()

            Text(Self.stopwatch(counter))
                .font(.system(size: split ? 34 : 88, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(split ? Color.secondary : Color.white)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.45, bounce: 0.15), value: split)

            splitBar(progress: progress, split: split)
                .frame(width: 180, height: 5)

            wordmark(visibleLetters: visible, showDot: visible == letters.count)
                .frame(height: 60)

            Spacer()
            Spacer()
        }
        .onChange(of: split) { _, now in
            if now, !didSplit {
                didSplit = true
                haptic.impactOccurred()
            }
        }
    }

    /// 주황으로 차오르다가 스플릿 순간 오른쪽 끝이 청록으로 끊긴다.
    private func splitBar(progress: Double, split: Bool) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule()
                    .fill(Color.run)
                    .frame(width: proxy.size.width * progress)
                if split {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Capsule()
                            .fill(Color.rest)
                            .frame(width: proxy.size.width * 0.3)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.25), value: split)
        }
    }

    private func wordmark(visibleLetters: Int, showDot: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                let shown = index < visibleLetters
                Text(String(letter))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 8)
                    .animation(.spring(duration: 0.3, bounce: 0.3), value: shown)
            }
            Circle()
                .fill(Color.rest)
                .frame(width: 9, height: 9)
                .opacity(showDot ? 1 : 0)
                .scaleEffect(showDot ? 1 : 0.3)
                .animation(.spring(duration: 0.3, bounce: 0.4), value: showDot)
        }
    }

    /// 1:34.7
    private static func stopwatch(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let rest = seconds - Double(minutes * 60)
        return String(format: "%d:%04.1f", minutes, rest)
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

#Preview {
    IntroView {}
}
