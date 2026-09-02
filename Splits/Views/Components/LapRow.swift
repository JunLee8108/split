//
//  LapRow.swift
//  Splits
//
//  세션 요약과 기록 상세가 같이 쓰는 랩 한 줄.
//

import SwiftUI

enum LapHighlight {
    case fastest
    case slowest

    /// 달리기 구간 중 가장 빠른 것과 느린 것. 달리기가 셋 이상일 때만 표시한다.
    /// 키는 랩 index.
    static func compute(for laps: [LapRecord]) -> [Int: LapHighlight] {
        let runs = laps.filter { $0.kind == .run && $0.pace != nil }
        guard runs.count >= 3 else { return [:] }
        let paces = runs.compactMap(\.pace)
        guard let fastest = paces.min(), let slowest = paces.max(), fastest != slowest else { return [:] }
        var result: [Int: LapHighlight] = [:]
        for lap in runs {
            if lap.pace == fastest { result[lap.index] = .fastest }
            else if lap.pace == slowest { result[lap.index] = .slowest }
        }
        return result
    }
}

struct LapRow: View {
    let lap: LapRecord
    let unit: DistanceUnit
    var highlight: LapHighlight? = nil

    var body: some View {
        HStack(spacing: 12) {
            Text("\(lap.index + 1)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 22, alignment: .trailing)
            StepBadge(kind: lap.kind)
            Text(Formatters.target(lap.target, unit: unit))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(Formatters.clock(lap.duration))
                .monospacedDigit()
            HStack(spacing: 4) {
                if let marker {
                    Image(systemName: marker)
                        .font(.caption2)
                        .foregroundStyle(lap.kind.tint)
                }
                Text(Formatters.pace(lap.pace, unit: unit))
                    .monospacedDigit()
                    .foregroundStyle(paceStyle)
            }
            .frame(width: 76, alignment: .trailing)
        }
        .font(.body)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var marker: String? {
        switch highlight {
        case .fastest?: "arrow.up"
        case .slowest?: "arrow.down"
        case nil: nil
        }
    }

    private var paceStyle: HierarchicalShapeStyle {
        switch highlight {
        case .fastest?: .primary
        case .slowest?: .secondary
        case nil: lap.kind.isRun ? .primary : .tertiary
        }
    }

    private var accessibilityText: String {
        var parts = ["\(lap.index + 1)번째, \(lap.kind.koreanName), \(Formatters.spokenDuration(lap.duration))"]
        if let spoken = Formatters.spokenPace(lap.pace, unit: unit) {
            parts.append("페이스 \(spoken)")
        }
        switch highlight {
        case .fastest?: parts.append("가장 빠름")
        case .slowest?: parts.append("가장 느림")
        case nil: break
        }
        return parts.joined(separator: ", ")
    }
}
