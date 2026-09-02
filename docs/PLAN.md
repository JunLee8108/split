# Splits — GPS 인터벌 러닝 앱 개발·디자인 계획 (v1, 2026-09-02)

## 0. 현재 상태
- Xcode SwiftUI + SwiftData 템플릿 그대로 (`Item` 샘플 모델, 리스트 화면 하나)
- 배포 타깃 iOS 26.5, 번들 `com.jun.Splits`
- CloudKit 엔티틀먼트는 있으나 컨테이너 ID 없음 → 1차에서는 사용 안 함
- Background Modes에 `location` 없음, 위치 권한 문구 없음 → Phase 1에서 추가

## 1. 범위 결정 (가정)
| 항목 | 결정 |
|---|---|
| 구간 종료 기준 | 거리·시간 둘 다. 구간마다 선택. 두 번 탭으로 수동 넘김 가능 |
| Apple Watch | 2차 |
| HealthKit | 1차 마지막 단계에 워크아웃 저장만 |
| 동기화 | 1차 로컬, 2차 CloudKit |
| 기기 | iPhone 세로 모드만 (iPad·가로 제거) |

### MVP
- 플랜 CRUD + 프리셋 3개 (400m×8, 3분/1분×6, 1km×4)
- 실시간 세션: 타이머, GPS 거리·페이스, 자동 구간 전환, 음성·햅틱, 백그라운드 추적, 일시정지·재개·종료
- 세션 저장: 랩, 총 거리·시간·평균 페이스, 경로
- 히스토리 목록 + 상세 (랩 테이블, 지도 경로)
- HealthKit 저장 (설정 토글)

### 2차
Live Activity / Dynamic Island, CloudKit, Apple Watch, 주간 통계, 플랜 공유

## 2. 파일 구조
```
Splits/
├── SplitsApp.swift
├── Models/        IntervalPlan(+Segment), Workout(+Lap, RoutePoint), Presets
├── Engine/        LocationManager, WorkoutEngine, SegmentTracker, Announcer
├── Views/         Plans/, Session/, History/, Settings/, Components/
├── Services/      HealthKitService, Formatters
└── Resources/
SplitsTests/       SegmentTrackerTests, WorkoutEngineTests, PaceMathTests
```
- 뷰는 상태만 그린다. 판단은 `WorkoutEngine`(`@Observable`) 하나가 맡는다.
- LocationManager → (정확도 20m 필터, 거리 누적) → Engine → SegmentTracker → Announcer / Lap 확정

## 3. 데이터 모델 (SwiftData)
- `IntervalPlan`: name, createdAt, segments(cascade), repeatCount, warmup, cooldown
- `Segment`: kind(run/rest), target(distance m | duration s, Codable enum), order
- `Workout`: startedAt, endedAt, totalDistance, movingTime, avgPace, planName(스냅샷), laps, route(Data)
- `Lap`: index, kind, distance, duration, avgPace, targetDescription
- `RoutePoint`: lat, lon, timestamp, lapIndex (구조체 배열 → Data 직렬화)
- 저장 단위는 항상 m / s / s·km⁻¹. 마일 표시는 Formatters에서만.

## 4. 개발 단계
| Phase | 내용 | 완료 기준 |
|---|---|---|
| 1 | 템플릿 정리, Info.plist(location, 권한 문구), 모델 4종, 프리셋, 테스트 골격 | 프리셋 3개가 목록에 뜬다 |
| 2 | LocationManager, WorkoutEngine 상태 머신, SegmentTracker | 화면 꺼도 거리·구간 이어짐, 전환 테스트 통과 |
| 3 | SessionView, 큰 숫자, 일시정지·종료, 음성·햅틱, 5초 카운트다운 | 실제 400m×4 러닝에서 전환 타이밍 확인 |
| 4 | 플랜 편집기 (구간 추가/삭제/순서, 거리·시간 토글, 반복, 웜업·쿨다운) | 새 플랜으로 세션 실행 |
| 5 | Workout 저장, 요약 시트, 히스토리, 상세(랩 테이블 + MapKit 경로) | 다음 날 기록을 열어 볼 수 있다 |
| 6 | HealthKit, 설정, 아이콘, 접근성, TestFlight | 본인 폰에서 일상 사용 |

### 기술 결정
- 거리 필터: horizontalAccuracy > 20m 폐기, 첫 5초 폐기, 속도 < 0.5m/s 정지 판정
- 현재 페이스: 최근 15초 이동 평균
- 경과 시간은 벽시계 기준 (백그라운드 타이머 지연 보정)
- 일시정지 중 위치는 받되 누적하지 않음
- 오디오 세션 `.duckOthers`
- 엔진 상태 30초마다 스냅샷 → 강제 종료 시 복구

## 5. 디자인 계획
### 원칙
- 한 화면, 한 숫자: 세션 중엔 "현재 구간에서 남은 것"만 크게
- 색이 상태를 말한다: Run 코랄 / Rest 청록, 세션 배경 전체가 구간 색으로
- 시스템 컴포넌트 우선. 커스텀은 세션 화면과 큰 숫자뿐
- 컨트롤은 엄지 범위(하단 1/3), 종료는 길게 누르기
- 세션 화면은 항상 어두운 배경 (야외 대비)

### 색
| 역할 | 라이트 | 다크 |
|---|---|---|
| Run (AccentColor) | #E0522B | #FF6B45 |
| Rest | #178F83 | #2FC2B3 |
| 세션 배경 | #101215 (항상) | |
| 앱 배경 / 글자 | systemGroupedBackground / Color.primary | |

### 타이포
- 큰 숫자: SF Pro Rounded Bold 96pt, `.monospacedDigit()`
- 보조 지표: SF Pro Semibold 22pt, 라벨 11pt 대문자
- 본문: Dynamic Type 기본
- 배지: SF Mono 12pt ("RUN 3/8", "400 m")
- 페이스 `4'32"`, 거리 1km 미만은 m, 이상은 소수 둘째 자리 km

### 화면
탭 3개: 플랜 / 기록 / 설정. 세션은 전체 화면 모달.
- 플랜 목록: 카드(이름 + 구성 요약), 하단 고정 시작 버튼, 스와이프 복제·삭제
- 플랜 편집: 구간 행(Run/Rest 토글, 거리·시간 피커), 드래그 정렬, 반복 스텝퍼, 총 예상치 실시간
- 세션: 상단 진행 바, 구간 배지 + 경과 시간, 큰 숫자(남은 거리/시간), 지표 3개(페이스·거리·구간 시간), 일시정지. 두 번 탭 = 수동 넘김, 길게 누르기 = 종료, 화면 항상 켜짐
- 세션 요약: 시트, 큰 숫자 3개 + 랩 테이블, 저장·삭제
- 기록: 날짜별 섹션, 미니 경로 썸네일
- 기록 상세: 지도(구간 색 경로) → 요약 → 랩 테이블
- 설정: 단위, 음성, 카운트다운 초, HealthKit, 자동 잠금 방지

### 음성·햅틱
| 시점 | 음성 | 햅틱 |
|---|---|---|
| 구간 시작 | "3번째 달리기, 400미터" | 강하게 2회 |
| 종료 5초 전 | "5, 4, 3, 2, 1" | 없음 |
| 회복 시작 | "회복, 1분 30초" | 길게 1회 |
| 매 1km | "1킬로미터, 4분 28초" | 가볍게 1회 |
| 완료 | "완료. 4킬로미터, 평균 4분 30초" | 성공 패턴 |

### 접근성
- 세션 외 화면은 시스템 라이트/다크 따름
- 큰 숫자는 고정 크기, 지표는 접근성 크기에서 2줄 재배치
- 색 + 텍스트 배지 병행
- VoiceOver: "달리기 3, 152미터 남음"

## 6. 리스크
| 항목 | 대응 |
|---|---|
| GPS 오차 (구간 ±10%) | 정확도 필터, 수동 넘김, 트랙 모드는 2차 |
| 백그라운드 종료 | 30초 스냅샷 + 복구 |
| 배터리 (1h ≈ 15–20%) | Best 정확도 유지, 회복 구간 화면 밝기 제안 |
| iOS 26.5 타깃 | 실기기 버전 확인, 필요 시 26.0으로 |
| 실외 검증 | GPX 재생 + Phase 3 실제 러닝 1회 |

## 진행 상황
- [x] Phase 1 — 템플릿 정리, Info.plist(location 백그라운드, 권한 문구), iPhone 세로 전용, 모델 4종, 프리셋 3개, 탭 골격(플랜·기록·설정)
- [x] Phase 2 — DistanceAccumulator / PaceCalculator / SegmentTracker / WorkoutEngine / LocationManager(CLLocationUpdate.liveUpdates + CLBackgroundActivitySession) / Announcer / WorkoutSession, 유닛 테스트 4파일
- [ ] Phase 3 — SessionView, 플랜에서 시작 버튼, 실외 검증
- [ ] Phase 4 — 플랜 편집기
- [ ] Phase 5 — 세션 요약 시트, 기록 상세(랩 테이블 + 지도)
- [ ] Phase 6 — HealthKit, 아이콘, 접근성, TestFlight

메모
- Xcode 없이 작성한 코드다. 첫 빌드에서 경고·오류가 나면 그 로그를 기준으로 고친다.
- 햅틱은 CoreHaptics 대신 UIKit 피드백 제너레이터를 썼다. 필요한 패턴이 단순해서 충분하다.
- `replaceSegments`는 기존 Segment를 관계에서만 떼어낸다. 편집기(Phase 4)에서는 빠진 Segment를 명시적으로 delete 한다.
