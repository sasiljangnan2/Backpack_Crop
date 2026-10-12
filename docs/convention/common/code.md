# 프론트 · 백엔드 공통 약속

이 문서에는 **프론트와 백엔드가 서로 맞춰야 하는 약속**만 있습니다.
코드 스타일은 언어마다 다르므로 각자의 문서를 따릅니다.

- 프론트: [frontend/flutter.md](../frontend/flutter.md)
- 백엔드: [backend/spring.md](../backend/spring.md)

## 1. API로 주고받는 데이터

| 항목 | 약속 | 프론트에서 | 백엔드에서 |
|---|---|---|---|
| JSON 키 | camelCase | DTO `fromJson` 키를 그대로 사용 | record 필드 이름 = JSON 키 |
| 시각 (언제) | ISO-8601 UTC `2026-10-12T03:00:00Z` | `DateTime.parse()` 후 `.toLocal()`로 표시 | `Instant` |
| 날짜 (며칠) | `2026-10-12` (시간 없음) | 보낼 때 `yyyy-MM-dd` 문자열로. **`toUtc().toIso8601String()` 금지** (한국 시간 기준 하루 전 날짜로 바뀜) | `LocalDate` |
| 에러 | `ErrorResponse` 형식 하나 | `code`(예: `NOT_TRIP_MEMBER`)로 분기, `message`는 화면에 그대로 표시 가능 | `GlobalExceptionHandler`가 생성 |
| URL | kebab-case, 복수형 | 상수로 모아서 사용 | `/api/trips/{tripId}/budget-items` |

API의 실제 모양은 [API 명세](../../api/README.md)가 기준입니다.

## 2. 도메인 이름 맞추기

같은 개념은 프론트 폴더 이름과 백엔드 패키지 이름을 같게 씁니다.

| 도메인 | 프론트 | 백엔드 |
|---|---|---|
| 여행 | `lib/features/trip/` | `com.backpackcorp.backpack.trip` |
| 정산 | `lib/features/settlement/` | `com.backpackcorp.backpack.settlement` |

새 도메인을 만들 때는 양쪽이 이름을 먼저 정합니다.

## 3. 둘 다 똑같이 지키는 것

- 약어도 단어처럼 쓴다: `JwtToken`, `apiUrl` (O) / `JWTToken`, `APIURL` (X)
- boolean은 `is`, `has`, `can`으로 시작한다: `isSettled`, `hasNext`
- 주석에는 **왜**를 쓴다
- 비밀번호, 토큰, 개인정보는 로그에 남기지 않는다
- API 주소와 키는 코드에 직접 쓰지 않는다

## ⚠️ 헷갈리기 쉬운 차이

프론트와 백엔드가 **서로 다르게** 쓰는 규칙입니다. 공통 규칙이 아니니 주의하세요.

| 항목 | 프론트 (Dart) | 백엔드 (Java) |
|---|---|---|
| 들여쓰기 | 스페이스 2칸 | 탭 |
| 한 줄 길이 | 80자 | 120자 |
| 문자열 따옴표 | 홑따옴표 `'여행'` | 쌍따옴표 `"여행"` (Java 문법) |
| 상수 이름 | `maxMemberCount` | `MAX_MEMBER_COUNT` |
| enum 값 | `ExpenseCategory.food` | `ErrorCode.NOT_TRIP_MEMBER` |
| 파일 이름 | `trip_list_screen.dart` | `TripService.java` |
| 로그 | `debugPrint()` | `log.info()` (`@Slf4j`) |
| 비밀 값 넣는 법 | `--dart-define` 또는 env 파일 | `.env` 파일 (`backend/.env.example`을 복사) |
| PR 전에 실행 | `dart format .` + `flutter analyze` | `./gradlew build` |
