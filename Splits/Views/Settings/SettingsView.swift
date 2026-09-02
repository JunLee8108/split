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
                Section("표시") {
                    Picker("거리 단위", selection: $unitRaw) {
                        ForEach(DistanceUnit.allCases, id: \.rawValue) { unit in
                            Text(unit.label).tag(unit.rawValue)
                        }
                    }
                    Toggle("세션 중 화면 켜 두기", isOn: $keepScreenOn)
                }

                Section {
                    Toggle("음성 안내", isOn: $voiceEnabled)
                    Stepper("종료 \(countdownSeconds)초 전 카운트다운", value: $countdownSeconds, in: 3...10)
                        .disabled(!voiceEnabled)
                } header: {
                    Text("안내")
                } footer: {
                    Text("시간 구간이 끝나기 전 숫자를 세어 줍니다. 거리 구간은 100m 남았을 때 한 번 알립니다.")
                }

                if health.isAvailable {
                    Section {
                        Toggle("Apple 건강에 저장", isOn: $saveToHealth)
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

                Section("정보") {
                    LabeledContent("버전", value: versionString)
                }
            }
            .navigationTitle("설정")
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
