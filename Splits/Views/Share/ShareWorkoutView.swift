//
//  ShareWorkoutView.swift
//  Splits
//
//  공유 시트. 카드 미리보기, 크기 선택, 이미지·텍스트 공유 버튼.
//

import SwiftUI
import UIKit

struct ShareWorkoutView: View {
    let workout: ShareableWorkout

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue
    @State private var format: ShareCardFormat = .feed
    @State private var rendered: UIImage?

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .metric }
    private var text: String { ShareText.summary(workout, unit: unit) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("크기", selection: $format) {
                    ForEach(ShareCardFormat.allCases) { format in
                        Text(format.label).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                ScrollView {
                    Group {
                        if let rendered {
                            Image(uiImage: rendered)
                                .resizable()
                                .scaledToFit()
                        } else {
                            ShareCardView(workout: workout, unit: unit, format: format)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 8)
                }

                VStack(spacing: 10) {
                    if let rendered {
                        ShareLink(
                            item: Image(uiImage: rendered),
                            preview: SharePreview(workout.planName, image: Image(uiImage: rendered))
                        ) {
                            Label("이미지로 공유", systemImage: "photo")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                    } else {
                        ProgressView()
                            .frame(height: 50)
                    }

                    ShareLink(item: text) {
                        Label("텍스트로 공유", systemImage: "text.quote")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .background(Color.screenBackground)
            .navigationTitle("공유")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .task(id: format) {
                rendered = nil
                rendered = render()
            }
        }
    }

    /// 카드를 3배 해상도 PNG로. 피드 1080×1350, 스토리 1080×1920.
    private func render() -> UIImage? {
        let size = format.size
        let renderer = ImageRenderer(
            content: ShareCardView(workout: workout, unit: unit, format: format)
                .frame(width: size.width, height: size.height)
        )
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }
}
