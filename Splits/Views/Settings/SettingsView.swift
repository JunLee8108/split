//
//  SettingsView.swift
//  Splits
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.distanceUnitKey) private var unitRaw = DistanceUnit.metric.rawValue
    @AppStorage(AppSettings.voiceEnabledKey) private var voiceEnabled = true
    @AppStorage(AppSettings.countdownSecondsKey) private var countdownSeconds = AppSettings.defaultCountdownSeconds
    @AppStorage(AppSettings.keepScreenOnKey) private var keepScreenOn = true

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
            }
            .navigationTitle("설정")
        }
    }
}

#Preview {
    SettingsView()
}
