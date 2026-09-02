//
//  StepBadge.swift
//  Splits
//
//  "RUN", "REST" 같은 짧은 배지. 색과 글자를 같이 써서 색만으로 구분하지 않는다.
//

import SwiftUI

extension StepKind {
    var tint: Color {
        switch self {
        case .run, .warmup: Color("Run")
        case .rest, .cooldown: Color("Rest")
        }
    }
}

struct StepBadge: View {
    let kind: StepKind
    var text: String? = nil

    var body: some View {
        Text(text ?? kind.badge)
            .font(.system(.caption, design: .monospaced).weight(.semibold))
            .tracking(0.5)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(kind.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(kind.tint)
            .accessibilityLabel(kind.koreanName)
    }
}

#Preview {
    HStack {
        StepBadge(kind: .run)
        StepBadge(kind: .rest)
        StepBadge(kind: .run, text: "RUN 3/8")
    }
    .padding()
}
