//
//  PlanListView.swift
//  Splits
//
//  홈. 마지막으로 뛴 플랜을 크게, 나머지는 카드로. 들어오자마자 한 번 눌러 뛸 수 있게.
//

import Foundation
import SwiftData
import SwiftUI

struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IntervalPlan.createdAt) private var plans: [IntervalPlan]
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue
    @AppStorage(AppSettings.lastPlanNameKey) private var lastPlanName = ""
    @State private var activePlan: IntervalPlan?
    @State private var isCreating = false
    @State private var isBrowsingTemplates = false

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }

    private var featured: IntervalPlan? {
        plans.first { $0.name == lastPlanName } ?? plans.first
    }

    var body: some View {
        NavigationStack {
            List {
                ScreenHeader(eyebrow: Date.now.formatted(.dateTime.month().day().weekday(.wide))) {
                    CircleIconMenu(systemImage: "plus", label: "플랜 추가") {
                        Button {
                            isCreating = true
                        } label: {
                            Label("직접 만들기", systemImage: "square.and.pencil")
                        }
                        Button {
                            isBrowsingTemplates = true
                        } label: {
                            Label("템플릿에서 고르기", systemImage: "square.grid.2x2")
                        }
                    }
                }
                .cardRow(top: 8, bottom: Metrics.headerGap)

                if let featured {
                    NavigationLink(value: featured) {
                        HeroPlanCard(plan: featured, unit: unit) {
                            activePlan = featured
                        }
                    }
                    .buttonStyle(.plain)
                    .cardRow()
                }

                if plans.isEmpty {
                    EmptyCard(
                        systemImage: "figure.run",
                        title: "첫 플랜을 골라 보세요",
                        message: "400m 반복, 야소 800, 파틀렉 같은 템플릿에서 고르거나 직접 구간을 짤 수 있어요.",
                        actionTitle: "템플릿에서 고르기",
                        action: { isBrowsingTemplates = true },
                        secondaryTitle: "직접 만들기",
                        secondaryAction: { isCreating = true }
                    )
                    .cardRow()
                } else {
                    SectionLabel("내 플랜")
                        .cardRow(bottom: 4)
                    ForEach(plans) { plan in
                        NavigationLink(value: plan) {
                            PlanCard(plan: plan, unit: unit)
                        }
                        .buttonStyle(.plain)
                        .cardRow()
                        .swipeActions(edge: .leading) {
                            Button {
                                activePlan = plan
                            } label: {
                                Label("시작", systemImage: "play.fill")
                            }
                            .tint(.run)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                modelContext.delete(plan)
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                            Button {
                                plan.duplicate(into: modelContext)
                            } label: {
                                Label("복제", systemImage: "doc.on.doc")
                            }
                            .tint(.secondary)
                        }
                        .contextMenu {
                            Button {
                                activePlan = plan
                            } label: {
                                Label("시작", systemImage: "play.fill")
                            }
                            Button {
                                plan.duplicate(into: modelContext)
                            } label: {
                                Label("복제", systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive) {
                                modelContext.delete(plan)
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: IntervalPlan.self) { plan in
                PlanDetailView(plan: plan)
            }
            .fullScreenCover(item: $activePlan) { plan in
                SessionView(plan: plan)
            }
            .sheet(isPresented: $isCreating) {
                PlanEditorView(plan: nil)
            }
            .sheet(isPresented: $isBrowsingTemplates) {
                TemplateLibraryView()
            }
        }
    }
}

/// 주황 히어로 카드. 플랜 이름과 구성, 그리고 시작 버튼.
struct HeroPlanCard: View {
    let plan: IntervalPlan
    let unit: DistanceUnit
    let onStart: () -> Void

    private var blueprint: PlanBlueprint { plan.blueprint }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(Color.run)
            // 장식. 카드 밖으로 삐져나가므로 터치는 받지 않는다.
            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 240, height: 240)
                .offset(x: 200, y: -110)
                .allowsHitTesting(false)
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 140, height: 140)
                .offset(x: 20, y: 120)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 14) {
                Text("다음 세션")
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text(Formatters.planSummary(blueprint, unit: unit))
                        .font(.system(.subheadline, design: .monospaced))
                        .opacity(0.85)
                        .lineLimit(1)
                }
                .foregroundStyle(.white)

                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        HeroChip(text: "\(blueprint.steps().count)구간")
                        if blueprint.plannedDuration > 0 {
                            HeroChip(text: Formatters.clock(blueprint.plannedDuration))
                        }
                    }
                    Spacer()
                    Button(action: onStart) {
                        Label("시작", systemImage: "play.fill")
                            .font(.headline)
                            .foregroundStyle(Color.run)
                            .padding(.horizontal, 18)
                            .frame(height: 44)
                            .background(.white, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(plan.name) 시작")
                }
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        // clipShape는 그리기만 자른다. 터치 영역도 카드 모양으로 고정한다.
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private struct HeroChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.18), in: Capsule())
    }
}

struct PlanCard: View {
    let plan: IntervalPlan
    let unit: DistanceUnit

    private var blueprint: PlanBlueprint { plan.blueprint }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(plan.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    ForEach(Array(blueprint.segments.prefix(3).enumerated()), id: \.offset) { _, segment in
                        StepBadge(kind: segment.kind, text: "\(segment.kind.badge) \(Formatters.target(segment.target, unit: unit))")
                    }
                    if blueprint.repeatCount > 1 {
                        Text("× \(blueprint.repeatCount)")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(totalLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .card()
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
    }

    private var totalLine: String {
        var parts = ["\(blueprint.steps().count)구간"]
        if blueprint.plannedDistance > 0 {
            parts.append(Formatters.distance(blueprint.plannedDistance, unit: unit))
        }
        if blueprint.plannedDuration > 0 {
            parts.append(Formatters.clock(blueprint.plannedDuration))
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    PlanListView()
        .modelContainer(for: [IntervalPlan.self, Segment.self, Workout.self, Lap.self], inMemory: true)
}
