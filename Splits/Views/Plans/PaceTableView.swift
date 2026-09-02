//
//  PaceTableView.swift
//  Splits
//
//  한 거리에 대해 기록 → km 페이스 → 마일 페이스 표. 행을 탭하면 그 시간이 목표가 된다.
//

import SwiftUI

nonisolated enum PaceTable {
    nonisolated struct Row: Identifiable, Hashable, Sendable {
        let seconds: TimeInterval
        let paceKm: TimeInterval
        var id: TimeInterval { seconds }
    }

    /// 2'30"/km 부터 10'00"/km 사이를 5초 단위로. 행이 60개를 넘으면 간격을 넓힌다.
    static func rows(meters: Double, fastestPace: TimeInterval = 150, slowestPace: TimeInterval = 600) -> [Row] {
        guard meters > 0 else { return [] }
        let tMin = (fastestPace * meters / 1000 / 5).rounded(.up) * 5
        let tMax = (slowestPace * meters / 1000 / 5).rounded(.down) * 5
        guard tMax >= tMin else { return [] }
        var step: TimeInterval = 5
        while (tMax - tMin) / step > 60 {
            step += 5
        }
        return stride(from: tMin, through: tMax, by: step).map { seconds in
            Row(seconds: seconds, paceKm: seconds / (meters / 1000))
        }
    }
}

struct PaceTableView: View {
    let meters: Double
    var selectedSeconds: TimeInterval? = nil
    var onSelect: ((TimeInterval) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    private var rows: [PaceTable.Row] { PaceTable.rows(meters: meters) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(rows) { row in
                        Button {
                            onSelect?(row.seconds)
                            dismiss()
                        } label: {
                            HStack {
                                Text("\(Formatters.clock(row.seconds)) (\(Int(row.seconds))초)")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(Formatters.pace(row.paceKm))/km")
                                    .frame(width: 96, alignment: .trailing)
                                Text("\(Formatters.pace(row.paceKm, unit: .imperial))/mi")
                                    .frame(width: 104, alignment: .trailing)
                            }
                            .font(.body.monospacedDigit())
                            .foregroundStyle(row.seconds == selectedSeconds ? Color.accentColor : Color.primary)
                            .fontWeight(row.seconds == selectedSeconds ? .semibold : .regular)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(Formatters.spokenDuration(row.seconds)), 킬로미터당 \(Formatters.spokenPace(row.paceKm) ?? ""), 마일당 \(Formatters.spokenPace(row.paceKm, unit: .imperial) ?? "")")
                    }
                } header: {
                    HStack {
                        Text("\(Formatters.distance(meters)) 기록")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("km 페이스")
                            .frame(width: 96, alignment: .trailing)
                        Text("mile 페이스")
                            .frame(width: 104, alignment: .trailing)
                    }
                    .textCase(nil)
                } footer: {
                    Text(onSelect == nil ? "참고용 표입니다." : "행을 탭하면 그 시간이 목표가 됩니다.")
                }
            }
            .navigationTitle("페이스 표")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PaceTableView(meters: 400, selectedSeconds: 90)
}
