# Splits for Apple Watch — 계획과 진행 (2026-10-07)

## 결정
- 워치 전용 앱(B안)으로 간다. 워치만 차고 나가도 Splits 엔진·안내·목표가 그대로 돈다.
- 애플 운동 앱으로 플랜을 보내는 WorkoutKit 방식(A안)은 하지 않는다. 필요해지면 나중에 버튼 하나로 붙일 수 있다.
- 세션은 시작한 기기가 끝까지 맡는다. 워치에서 시작하면 워치가 GPS·엔진·건강 저장을 하고, 끝난 기록만 iPhone으로 보낸다.

## 구조
```
Shared/          iPhone·워치 두 타깃이 같이 컴파일한다. UI 없음.
├── Engine/      WorkoutEngine, SegmentTracker(+LapRecord, GoalSummary), PaceMath, LocationManager, AnnouncementScript
├── Models/      PlanBlueprint, SegmentTarget, RoutePoint
├── Services/    AppSettings(+SessionSettings), Formatters, SessionReadout
└── Sync/        SessionLink(WCSession 래퍼), SyncPayload(WatchContext, SyncCoding)
Splits/          iPhone 전용. SwiftData 모델, 화면, Announcer(UIKit 햅틱), WorkoutSession, HealthKitService, PhoneSync
SplitsWatch/     watchOS 전용
├── Session/     WatchWorkoutSession, HealthRecorder(HKWorkoutSession), WatchAnnouncer(WKHaptic)
├── Sync/        WatchSync
└── Views/       PlanListView, SessionScreen, MetricsPage, ControlsPage, SummaryPage
```
- 엔진은 그대로다. 시간은 `tick(now:)`, 위치는 `ingest(_:)`로 받으니 기기만 바꿔 끼우면 된다.
- 안내 문장과 진동의 "의미"는 `AnnouncementScript` 하나가 정한다. 소리·진동을 실제로 내는 쪽만 기기별이다.
- 세션 화면 큰 숫자 두 개도 `SessionReadout` 하나에서 나온다. iPhone과 워치가 같은 값을 같은 말로 보여 준다.

## 데이터 흐름
| 방향 | 내용 | 수단 | 시점 |
|---|---|---|---|
| iPhone → 워치 | 플랜 목록, 마지막 플랜, 세션 설정(단위·음성·카운트다운·이정표·건강 저장) | `updateApplicationContext` (최신 하나만) | SwiftData 저장, UserDefaults 변경, 워치 앱 설치 시. 0.5초 디바운스, 같은 내용이면 생략 |
| 워치 → iPhone | 저장한 세션 `WorkoutSummary` JSON | `transferFile` (outbox 폴더, 성공 후 삭제) | 요약에서 저장할 때. 실패분은 다음 활성화 때 재전송 |

- 워치는 받은 설정을 자기 UserDefaults에 같은 `AppSettings` 키로 쓴다. 그래서 세션 코드는 iPhone과 똑같이 `AppSettings`를 읽는다.
- iPhone은 같은 시작 시각의 기록이 이미 있으면 받은 세션을 버린다(중복 전송 방어).
- 워치 기록은 `Workout.source = "watch"`로 표시하고 기록 카드에 워치 아이콘을 단다.
- 건강 앱: 워치 세션은 워치가 `HKLiveWorkoutBuilder`로 저장한다(심박·칼로리 포함). iPhone은 워치 기록을 건강 앱에 다시 쓰지 않는다. "Apple 건강에 저장"이 꺼져 있으면 워치도 버린다.
  - 건강 앱의 거리는 워치가 직접 잰 값, Splits 기록의 거리는 엔진 값이라 조금 다를 수 있다. 경로는 둘 다 엔진이 인정한 점이다.

## 워치 화면
- 플랜 목록: 마지막 플랜 맨 위(최근 표시), 누르면 시작. 처음 열 때 건강 권한을 묻는다.
- 카운트다운 3초: 그동안 GPS와 심박 센서를 깨운다. 초마다 click 진동.
- 세션: 왼쪽 조작(종료·일시정지/재개·다음 구간), 가운데 숫자. 운동 앱과 같은 배치.
  - 숫자 화면: 구간 배지·경과, 진행 바, 남은 거리/시간(46pt), 목표 줄(구간 색), 페이스·심박·총 거리.
  - 배경은 구간 색을 옅게. 상시 표시(손목 내림)에서는 색과 진행 바를 빼고 숫자만.
  - 종료는 확인을 한 번 더 받는다. 세션은 모달이 아니라 목록 자리에 들어서서 실수로 닫히지 않는다.
- 요약: 거리·시간·평균 페이스·목표 달성, 저장/버리기, 랩 목록.

## 진동 매핑
| 의미 | iPhone | 워치 |
|---|---|---|
| 달리기·워밍업 시작 | heavy ×2 | `.start` |
| 회복·쿨다운 시작 | heavy | `.stop` |
| 목표 시간 초과 | heavy | `.failure` |
| 이정표·1km·일시정지·재개 | light | `.notification` |
| 종료 직전 카운트다운 | 없음(음성) | `.click` |
| 완료 | success | `.success` |

## 진행
- [x] W0 공유 코드 정리 — Shared/ 폴더, AnnouncementScript·SessionReadout 분리, Codable, SessionSettings. iPhone 동작 변화 없음
- [x] W1 워치 타깃 — SplitsWatch(watchOS 26, `com.jun.Splits.watchkitapp`), Embed Watch Content, Info.plist(workout-processing, 권한 문구), HealthKit 엔티틀먼트, 아이콘·색
- [x] W2 iPhone → 워치 동기화 — SessionLink, PhoneSync, WatchSync, 테스트
- [x] W3 워치 세션 — HealthRecorder, WatchAnnouncer, WatchWorkoutSession
- [x] W4 워치 화면 — 목록, 카운트다운, 조작·숫자 페이지, 요약
- [x] W5 워치 → iPhone 기록 — outbox 파일 전송, iPhone 가져오기, 워치 아이콘
- [ ] Xcode 첫 빌드와 실기기 확인 (아래 체크리스트)

## 첫 빌드 전에 Xcode에서
1. Signing & Capabilities → SplitsWatch 타깃에도 Team을 고른다. HealthKit은 엔티틀먼트에, Background Modes(Workout processing)는 Info.plist에 이미 있다.
2. 스킴이 자동으로 생기지 않으면 Product > Scheme > New Scheme에서 SplitsWatch를 만든다.
3. 실기기 watchOS가 26 미만이면 SplitsWatch의 Minimum Deployments를 낮춘다(최소 11. `CLLocationUpdate`의 stationary 등).
4. 빌드 오류·경고가 나면 로그를 그대로 붙여 주면 고친다. 이 코드는 Xcode 없이 작성했다.

## 실기기 확인
- [ ] iPhone에서 플랜을 만들거나 고치면 몇 초 안에 워치 목록에 반영되는지
- [ ] iPhone 설정(단위·음성·카운트다운)을 바꾸면 다음 워치 세션에 반영되는지
- [ ] 워치만 차고 400m × 4: 자동 전환, 진동, 손목을 내린 채 구간이 넘어가는지
- [ ] 에어팟을 연결했을 때 음성 안내가 들리는지. 워치 스피커만으로는 얼마나 들리는지
- [ ] 저장 후 iPhone 기록 탭에 워치 아이콘과 함께 나타나는지(iPhone이 멀리 있다가 돌아온 경우 포함)
- [ ] 건강 앱에 러닝 + 경로 + 심박이 한 번만 저장되는지
- [ ] 위치·건강 권한을 거부했을 때 배너와 안내 문구

## 다음에 할 수 있는 것
- 손가락 더블 탭(`handGestureShortcut(.primaryAction)`)을 다음 구간이나 일시정지에 연결
- 워치 컴플리케이션 / 스마트 스택: "마지막 플랜 시작"
- 달리는 동안 iPhone에서도 보기(HKWorkoutSession 미러링)
- 워치 전용 설정(음성은 끄고 진동만 등)
- 구간 경계를 HKWorkoutEvent로 남겨 건강 앱에서 인터벌로 보이게
