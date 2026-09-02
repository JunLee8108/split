//
//  SegmentEditorView.swift
//  Splits
//
//  구간 하나의 종류와 목표를 고르는 시트. 종류와 목표 방식은 세그먼트 컨트롤, 값은 휠.
//

import SwiftUI

struct SegmentEditorView: View {
    let unit: DistanceUnit
    let onDone: (SegmentDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: StepKind
    @State private var isDistance: Bool
    @State private var meters: Double
    @State private var seconds: TimeInterval
    private let id: UUID

    init(segment: SegmentDraft, unit: DistanceUnit, onDone: @escaping (SegmentDraft) -> Void) {
        self.unit = unit
        self.onDone = onDone
        self.id = segment.id
        _kind = State(initialValue: segment.kind)
        _isDistance = State(initialValue: segment.target.isDistance)
        _meters = State(initialValue: segment.target.meters ?? 400)
        _seconds = State(initialValue: segment.target.seconds ?? 90)
    }

    private var target: SegmentTarget {
        isDistance ? .distance(meters) : .duration(seconds)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("종류", selection: $kind) {
                    Text("달리기").tag(StepKind.run)
                    Text("회복").tag(StepKind.rest)
                }
                .pickerStyle(.segmented)

                Picker("목표", selection: $isDistance) {
                    Text("거리").tag(true)
                    Text("시간").tag(false)
                }
                .pickerStyle(.segmented)

                Group {
                    if isDistance {
                        DistanceWheel(meters: $meters, unit: unit)
                    } else {
                        DurationWheel(seconds: $seconds)
                    }
                }
                .frame(maxHeight: .infinity)

                HStack(spacing: 8) {
                    StepBadge(kind: kind)
                    Text(Formatters.target(target, unit: unit))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .navigationTitle("구간")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        onDone(SegmentDraft(id: id, kind: kind, target: target))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

/// 자주 쓰는 거리 목록. 현재 값이 목록에 없으면 끼워 넣는다.
struct DistanceWheel: View {
    @Binding var meters: Double
    let unit: DistanceUnit

    static let options: [Double] = [
        100, 200, 300, 400, 500, 600, 800, 1000, 1200, 1500, 1600, 2000, 2500, 3000, 4000, 5000, 8000, 10000,
    ]

    private var options: [Double] {
        if Self.options.contains(meters) { return Self.options }
        return (Self.options + [meters]).sorted()
    }

    var body: some View {
        Picker("거리", selection: $meters) {
            ForEach(options, id: \.self) { value in
                Text(Formatters.distance(value, unit: unit)).tag(value)
            }
        }
        .pickerStyle(.wheel)
        .accessibilityLabel("목표 거리")
    }
}

/// 분·초 두 휠. 초는 5초 단위.
struct DurationWheel: View {
    @Binding var seconds: TimeInterval

    private var minutes: Binding<Int> {
        Binding(
            get: { Int(seconds) / 60 },
            set: { seconds = TimeInterval($0 * 60 + Int(seconds) % 60) }
        )
    }

    private var remainder: Binding<Int> {
        Binding(
            get: { (Int(seconds) % 60) / 5 * 5 },
            set: { seconds = TimeInterval((Int(seconds) / 60) * 60 + $0) }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            Picker("분", selection: minutes) {
                ForEach(0..<60, id: \.self) { m in
                    Text("\(m)분").tag(m)
                }
            }
            .pickerStyle(.wheel)
            .accessibilityLabel("분")

            Picker("초", selection: remainder) {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { s in
                    Text("\(s)초").tag(s)
                }
            }
            .pickerStyle(.wheel)
            .accessibilityLabel("초")
        }
    }
}
