//
//  SettingsView.swift
//  Splits
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue
    @AppStorage(AppSettings.voiceEnabledKey) private var voiceEnabled = true
    @AppStorage(AppSettings.countdownSecondsKey) private var countdownSeconds = AppSettings.defaultCountdownSeconds
    @AppStorage(AppSettings.keepScreenOnKey) private var keepScreenOn = true
    @AppStorage(AppSettings.saveToHealthKey) private var saveToHealth = false

    @State private var healthAuthorizationFailed = false

    private var health: HealthKitService { HealthKitService.shared }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $unitRaw) {
                        ForEach(DistanceUnit.allCases, id: \.rawValue) { unit in
                            Text(unit.label).tag(unit.rawValue)
                        }
                    } label: {
                        SettingsRowLabel(title: "거리 단위", systemImage: "ruler", tint: .gray)
                    }
                    Toggle(isOn: $keepScreenOn) {
                        SettingsRowLabel(title: "세션 중 화면 켜 두기", systemImage: "sun.max.fill", tint: .gray)
                    }
                } header: {
                    Text("표시")
                }

                Section {
                    Toggle(isOn: $voiceEnabled) {
                        SettingsRowLabel(title: "음성 안내", systemImage: "speaker.wave.2.fill", tint: .run)
                    }
                    Stepper(value: $countdownSeconds, in: 3...10) {
                        SettingsRowLabel(title: "종료 \(countdownSeconds)초 전 카운트다운", systemImage: "timer", tint: .run)
                    }
                    .disabled(!voiceEnabled)
                } header: {
                    Text("안내")
                } footer: {
                    Text("시간 구간이 끝나기 전 숫자를 세어 줍니다. 거리 구간은 100m 남았을 때 한 번 알립니다.")
                }

                if health.isAvailable {
                    Section {
                        Toggle(isOn: $saveToHealth) {
                            SettingsRowLabel(title: "Apple 건강에 저장", systemImage: "heart.fill", tint: .rest)
                        }
                        .onChange(of: saveToHealth) { _, enabled in
                            guard enabled else { return }
                            Task {
                                do {
                                    try await health.requestAuthorization()
                                    healthAuthorizationFailed = !health.isAuthorized
                                } catch {
                                    healthAuthorizationFailed = true
                                }
                            }
                        }
                    } header: {
                        Text("건강")
                    } footer: {
                        if healthAuthorizationFailed {
                            Text("건강 앱에서 Splits의 운동 쓰기 권한을 허용해야 저장됩니다. 설정 > 건강 > 데이터 접근 및 기기에서 바꿀 수 있어요.")
                        } else {
                            Text("저장한 세션이 러닝 운동으로 건강 앱에 기록됩니다. 경로도 함께 저장돼요.")
                        }
                    }
                }

                Section {
                    LabeledContent {
                        Text(versionString)
                            .foregroundStyle(.secondary)
                    } label: {
                        SettingsRowLabel(title: "버전", systemImage: "info", tint: .gray)
                    }
                } footer: {
                    Text("Splits · GPS 인터벌 러닝")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
