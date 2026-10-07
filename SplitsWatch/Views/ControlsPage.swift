//
//  ControlsPage.swift
//  SplitsWatch
//
//  숫자 화면 왼쪽. 종료·일시정지·다음 구간. 종료는 한 번 더 묻는다.
//

import SwiftUI

struct ControlsPage: View {
    let session: WatchWorkoutSession
    /// 재개하면 숫자 화면으로 돌아간다.
    let onResume: () -> Void
    let onEnd: () -> Void

    @State private var confirmEnd = false

    private var state: WorkoutState { session.engine.state }
    private var tint: Color { (session.engine.currentStep?.kind ?? .run).tint }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ControlButton(title: "종료", systemImage: "xmark", tint: .red) {
                    confirmEnd = true
                }
                if state == .paused {
                    ControlButton(title: "재개", systemImage: "play.fill", tint: tint) {
                        session.resume()
                        onResume()
                    }
                } else {
                    ControlButton(title: "일시정지", systemImage: "pause.fill", tint: .yellow) {
                        session.pause()
                    }
                }
            }
            ControlButton(title: "다음 구간", systemImage: "forward.end.fill", tint: .white) {
                session.skipStep()
            }
            .disabled(session.engine.currentStep == nil)

            if session.isBackgroundUnavailable {
                Text("건강 권한이 없어 손목을 내리면 멈출 수 있어요.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog("세션을 끝낼까요?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("종료", role: .destructive, action: onEnd)
            Button("계속", role: .cancel) {}
        }
    }
}

private struct ControlButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.title3)
            }
            .tint(tint)
            Text(title)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}
