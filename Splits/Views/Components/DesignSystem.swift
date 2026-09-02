//
//  DesignSystem.swift
//  Splits
//
//  랜딩 화면 공용 규칙. 좌우 20, 카드 안쪽 16, 카드 사이 12, 카드 반경 20.
//

import SwiftUI
import UIKit

extension Color {
    static let screenBackground = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let cardSecondary = Color(.tertiarySystemGroupedBackground)
    // Color.run / Color.rest 는 Xcode가 색 에셋에서 자동 생성한다.
}

enum Metrics {
    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let cardRadius: CGFloat = 20
}

struct CardModifier: ViewModifier {
    var padding: CGFloat
    var background: Color

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = Metrics.cardPadding, background: Color = .card) -> some View {
        modifier(CardModifier(padding: padding, background: background))
    }
}

/// 화면 맨 위 한 줄. 왼쪽은 작은 아이브로우, 오른쪽은 동작 버튼.
struct ScreenHeader<Trailing: View>: View {
    let eyebrow: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            Text(eyebrow)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            trailing
        }
        .frame(minHeight: 36)
        .padding(.horizontal, 4)
    }
}

/// 원형 아이콘 버튼. 헤더 오른쪽에 쓴다.
struct CircleIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Color.card, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel(label)
    }
}

/// 원형 아이콘 메뉴. CircleIconButton과 같은 모양.
struct CircleIconMenu<Content: View>: View {
    let systemImage: String
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        Menu {
            content
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Color.card, in: Circle())
                .contentShape(Circle())
        }
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel(label)
    }
}

struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 큰 숫자 + 작은 라벨.
struct StatTile: View {
    let value: String
    let label: String
    var size: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2.weight(.medium))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// 설정 행 왼쪽의 색 사각형 아이콘 + 제목.
struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(title)
        }
    }
}

/// 빈 상태 카드. 설명 한 줄과 행동 버튼 하나.
struct EmptyCard: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                }
                if let secondaryTitle, let secondaryAction {
                    Button(secondaryTitle, action: secondaryAction)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                }
            }
            .padding(.top, 4)
        }
        .card(padding: 20)
    }
}
