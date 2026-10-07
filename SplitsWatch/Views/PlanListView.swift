//
//  PlanListView.swift
//  SplitsWatch
//
//  iPhone에서 받은 플랜 목록. 마지막으로 뛴 플랜을 맨 위에 둔다. 누르면 바로 시작한다.
//

import SwiftUI

struct PlanListView: View {
    let onStart: (PlanBlueprint) -> Void

    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue

    private var sync: WatchSync { .shared }
    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }

    /// 마지막 플랜을 맨 앞으로. 이름이 같은 플랜이 여럿이면 첫 번째만 올린다.
    private var rows: [PlanRowItem] {
        let items = sync.plans.enumerated().map { offset, plan in
            PlanRowItem(id: offset, plan: plan, isLast: false)
        }
        guard let lastIndex = items.firstIndex(where: { $0.plan.name == sync.lastPlanName }) else {
            return items
        }
        var featured = items[lastIndex]
        featured.isLast = true
        var others = items
        others.remove(at: lastIndex)
        return [featured] + others
    }

    var body: some View {
        NavigationStack {
            List {
                if sync.plans.isEmpty {
                    Text(sync.hasReceivedContext
                         ? "플랜이 없어요. iPhone의 Splits에서 플랜을 만들어 주세요."
                         : "iPhone에서 Splits를 열면 플랜이 여기에 나타나요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(rows) { row in
                        Button {
                            onStart(row.plan)
                        } label: {
                            PlanRow(plan: row.plan, unit: unit, isLast: row.isLast)
                        }
                    }
                }
            }
            .navigationTitle("Splits")
        }
        .task {
            // 첫 세션 카운트다운 중에 권한 창이 뜨지 않게 미리 묻는다.
            await HealthRecorder().requestAuthorization()
        }
    }
}

private struct PlanRowItem: Identifiable {
    /// iPhone 목록에서의 위치.
    let id: Int
    let plan: PlanBlueprint
    var isLast: Bool
}

private struct PlanRow: View {
    let plan: PlanBlueprint
    let unit: DistanceUnit
    let isLast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if isLast {
                Text("최근")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(StepKind.run.tint)
            }
            Text(plan.name)
                .font(.headline)
                .lineLimit(2)
            Text(Formatters.planSummary(plan, unit: unit))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }
}
