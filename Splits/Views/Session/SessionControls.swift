//
//  SessionControls.swift
//  Splits
//
//  화면 하단, 엄지 범위. 달리는 중엔 일시정지 하나. 멈춘 뒤에 재개와 길게 눌러 종료.
//

import SwiftUI

struct SessionControls: View {
    let session: WorkoutSession
    let tint: Color
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            switch session.engine.state {
            case .running:
                Button {
                    session.pause()
                } label: {
                    Label("일시정지", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.12), in: Capsule())
                .font(.headline)

            case .paused:
                HStack(spacing: 10) {
                    Button {
                        session.resume()
                    } label: {
                        Label("재개", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .background(tint, in: Capsule())
                    .foregroundStyle(.white)
                    .font(.headline)

                    HoldToFinishButton(action: onFinish)
                }

            case .idle, .finished:
                ProgressView()
                    .frame(height: 56)
            }

            Text(hint)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var hint: String {
        switch session.engine.state {
        case .running: "화면을 두 번 탭하면 다음 구간으로"
        case .paused: "종료는 1초 동안 길게"
        case .idle, .finished: " "
        }
    }
}

/// 실수로 끝나지 않도록 1초 이상 눌러야 한다.
struct HoldToFinishButton: View {
    let action: () -> Void
    @State private var isPressing = false

    var body: some View {
        Label("길게 눌러 종료", systemImage: "stop.fill")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Capsule())
            .background(.white.opacity(isPressing ? 0.3 : 0.12), in: Capsule())
            .scaleEffect(isPressing ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: isPressing)
            .onLongPressGesture(minimumDuration: 1.0, maximumDistance: 20) {
                action()
            } onPressingChanged: { pressing in
                isPressing = pressing
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("1초 동안 길게 누르면 세션을 끝냅니다")
    }
}
