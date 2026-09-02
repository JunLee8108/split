# TestFlight 체크리스트

## Xcode에서 한 번만
1. **Signing & Capabilities** — Team 선택. 자동 서명이면 아래 capability가 App ID에 등록된다.
   - Background Modes: Location updates (Info.plist에 이미 있음)
   - HealthKit (엔티틀먼트에 이미 있음. 서명 오류가 나면 + Capability로 HealthKit을 한 번 추가했다 지운다)
   - iCloud / Push는 템플릿이 남긴 것. 1차에서는 쓰지 않으니 서명이 걸리면 엔티틀먼트에서 지워도 된다.
2. **배포 타깃** — 실기기 iOS 버전이 26.5 미만이면 General > Minimum Deployments를 낮춘다. 코드 변경 없음.
3. **버전** — General > Identity: Version 1.0, Build 1. 업로드마다 Build만 올린다.

## 빌드 전 확인
- [ ] 시뮬레이터에서 시간 기반 플랜(3분/1분 × 6) 한 바퀴: 구간 전환, 카운트다운 음성, 요약 저장
- [ ] 실기기 실외에서 400m × 4: 자동 전환 거리 오차 확인, 백그라운드(화면 끔)에서도 이어지는지
- [ ] 설정 > Apple 건강에 저장 켠 뒤 세션 저장 → 건강 앱 운동 탭에 러닝이 보이는지
- [ ] 위치 권한 거부 상태에서 세션 시작 → 배너와 설정 열기 동작
- [ ] 접근성 큰 글씨(설정 > 손쉬운 사용 > 더 큰 텍스트)에서 세션 화면 지표가 세로로 바뀌는지

## 업로드
1. Product > Archive (Any iOS Device)
2. Organizer > Distribute App > TestFlight & App Store > Upload
3. App Store Connect > TestFlight > 내부 테스터에 본인 추가. `ITSAppUsesNonExemptEncryption = false`가 있어 수출 규정 질문은 건너뛴다.

## 심사 시 물어볼 만한 것
- 위치 권한 문구: "달리는 동안 거리와 페이스를 측정하고 구간을 자동으로 전환하기 위해 위치가 필요합니다."
- 건강 쓰기 문구: "완료한 인터벌 세션을 러닝 운동으로 건강 앱에 저장하기 위해 필요합니다."
- 백그라운드 위치는 세션 중에만 켜진다 (CLBackgroundActivitySession, 세션 종료 시 invalidate).
