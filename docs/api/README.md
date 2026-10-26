# API 명세

기준: [ERD](../erd/README.md) · [`V1__init.sql`](../../backend/src/main/resources/db/migration/V1__init.sql)

> ✅ 표시는 구현된 API다. 게스트 참여(`/api/trips/join/guest`)만 **아직 초안**이다.
> 구현하면서 바뀌는 부분은 이 문서도 같이 고친다. ⚠️ 표시는 팀이 정해야 하는 부분이다.

## 1. 공통

### 기본

- Base URL: `/api`
- 요청·응답: `application/json`, 필드는 camelCase
- ID: UUID 문자열 (`"0192f3a1-..."`)
- 날짜 `YYYY-MM-DD`, 시간 `HH:mm`, 시각은 ISO-8601 UTC (`2026-10-12T03:00:00Z`)
- 금액: 원화는 정수(`12000`), 외화는 소수 둘째 자리까지 숫자, 환율은 소수 여섯째 자리까지 숫자

### 인증

| 대상 | 헤더 |
|---|---|
| 회원 | `Authorization: Bearer {accessToken}` |
| 게스트 ⚠️ | `X-Guest-Token: {guestToken}` (게스트 인증 방식 미정. `trip_members.guest_token_hash`에 해시만 저장) |

- 액세스 토큰이 만료되면 `401 TOKEN_EXPIRED` → 앱은 `POST /api/auth/reissue`로 재발급
- 그 밖의 `401`은 다시 로그인

### 권한

- 여행 하위 API(`/api/trips/{tripId}/...`)는 그 여행의 **현재 멤버**(`left_at IS NULL`)만 쓸 수 있다. 아니면 `403 NOT_TRIP_MEMBER` (여행이 없어도 같은 응답)
- 🔑 표시는 **방장(HOST)만**. 아니면 `403 NOT_TRIP_HOST`

### 목록 응답 (커서)

무한 스크롤 목록은 `?cursor={nextCursor}&size=20`으로 부르고 아래 형식으로 받는다. 첫 페이지는 `cursor` 없이 부른다.

```json
{ "content": [ ... ], "nextCursor": "0192f3a1-...", "hasNext": true }
```

### 에러 응답

```json
{
  "timestamp": "2026-10-12T03:00:00Z",
  "status": 400,
  "code": "VALIDATION_ERROR",
  "message": "요청 데이터 유효성 검사에 실패했습니다.",
  "details": { "name": "1~20자로 입력해 주세요." }
}
```

| code | status | 설명 |
|---|---|---|
| `BAD_REQUEST` | 400 | 잘못된 요청 |
| `VALIDATION_ERROR` | 400 | 필드 검증 실패. `details`에 필드별 메시지 |
| `UNAUTHORIZED` | 401 | 인증 필요 |
| `TOKEN_EXPIRED` | 401 | 액세스 토큰 만료 → 재발급 |
| `FORBIDDEN` | 403 | 권한 없음 |
| `NOT_TRIP_MEMBER` | 403 | 여행 멤버가 아님 |
| `NOT_TRIP_HOST` | 403 | 방장이 아님 |
| `NOT_FOUND` | 404 | 리소스 없음 |
| `METHOD_NOT_ALLOWED` | 405 | 지원하지 않는 메서드 |
| `CONFLICT` | 409 | 중복이거나 현재 상태와 충돌 (이메일 중복, 동시 수정 등) |
| `PAYLOAD_TOO_LARGE` | 413 | 파일이 너무 큼 |
| `INVALID_IMAGE` | 400 | JPG·PNG가 아닌 이미지 |
| `INTERNAL_SERVER_ERROR` | 500 | 서버 오류 |

| `INVALID_CREDENTIALS` | 401 | 이메일 또는 비밀번호 불일치 (구분하지 않음) |
| `TOO_MANY_LOGIN_ATTEMPTS` | 429 | 같은 이메일로 15분 안에 5번 실패 |
| `EMAIL_ALREADY_EXISTS` | 409 | 이미 가입된 이메일 |
| `INVALID_PASSWORD` | 400 | 현재 비밀번호 불일치 (비밀번호 변경 · 탈퇴) |
| `USER_NOT_FOUND` | 404 | 탈퇴했거나 없는 회원 |
| `INVITE_CODE_NOT_FOUND` | 404 | 없는 초대 코드 |
| `TRIP_FULL` | 409 | 여행 인원(30명) 초과 |
| `TRIP_CURRENCY_LOCKED` | 409 | 지출이 있는 여행의 통화 변경 |
| `TRIP_PERIOD_CONFLICT` | 409 | 바꿀 기간 밖에 일정이 있음 |
| `SCHEDULE_NOT_FOUND` | 404 | 일정 없음 |
| `INVALID_TIME_RANGE` | 400 | 종료 시간이 시작 시간보다 이르거나 같음 |
| `SCHEDULE_OUT_OF_TRIP` | 400 | 여행 기간 밖 날짜 |
| `SCHEDULE_OVERLAP` | 409 | 다른 일정과 시간이 겹침. `details`에 겹친 일정 |
| `SCHEDULE_LOCKED` | 409 | 고정된 일정 |
| `VERSION_CONFLICT` | 409 | 조회 후 다른 사람이 먼저 수정함 (일정 · 지출) |
| `EXPENSE_NOT_FOUND` | 404 | 지출 없음 |
| `NOT_EXPENSE_EDITOR` | 403 | 결제자 · 작성자 · 방장이 아님 |
| `NOTHING_TO_SETTLE` | 409 | 공유할 송금 내역이 없음 |
| `SETTLEMENT_SHARE_NOT_FOUND` | 404 | 공유한 정산 없음 |
| `EXCHANGE_RATE_NOT_FOUND` | 404 | 환율 정보 없음 (그 날짜 이전 값도 없음) |
| `INVALID_EXPENSE` | 400 | 지출 금액·분담 규칙 위반. `details`에 문제 위치 |
| `PREPAID_RATE_NOT_SET` | 400 | 결제자의 선불 환율이 없음 |
| `BUDGET_ITEM_NOT_FOUND` | 404 | 예산 항목 없음 |
| `TASK_NOT_FOUND` | 404 | 준비 업무 없음 (남의 개인 업무도 같은 응답) |
| `NOT_TASK_OWNER` | 403 | 함께 할 업무를 만든 사람 · 담당자 · 방장이 아님 (삭제) |
| `POLL_NOT_FOUND` | 404 | 투표 없음 |
| `POLL_CLOSED` | 409 | 마감됐거나 마감 시각이 지난 투표 |
| `INVALID_POLL_OPTION` | 400 | 그 투표의 후보가 아님 |
| `NOT_POLL_MANAGER` | 403 | 투표를 만든 사람 · 방장이 아님 (마감 · 삭제) |
| `NOTIFICATION_NOT_FOUND` | 404 | 내 알림이 아님 |

도메인별 코드(`USER_NOT_FOUND` 등)는 구현하면서 `ErrorCode`에 추가하고 이 표에도 적는다.

### 낙관적 락

`schedules`, `expenses`는 `version`을 가진다. 수정 요청에 조회 때 받은 `version`을 함께 보내고, 그 사이 다른 사람이 고쳤으면 `409 VERSION_CONFLICT`를 받는다(`details.version`에 현재 값). 앱은 다시 조회해서 보여 준다. 저장 직전의 동시 충돌은 `409 CONFLICT`로 온다.

---

## 2. 엔드포인트 목록

| 영역 | 메서드 | URL | 설명 |
|---|---|---|---|
| 인증 | POST | `/api/auth/signup` | 회원가입 |
| | POST | `/api/auth/login` | 로그인 |
| | POST | `/api/auth/reissue` | 토큰 재발급 |
| | POST | `/api/auth/logout` | 로그아웃 |
| 회원 | GET | `/api/users/me` | 내 정보 (`/api/me`도 같음) |
| | PATCH | `/api/users/me` | 이름 변경 |
| | PATCH | `/api/users/me/password` | 비밀번호 변경 |
| | PATCH | `/api/users/me/notification-settings` | 알림 설정 |
| | DELETE | `/api/users/me` | 탈퇴 |
| 여행 | POST | `/api/trips` | 여행 만들기 |
| | GET | `/api/trips` | 내 여행 목록 |
| | GET | `/api/trips/{tripId}` | 여행 상세 |
| | PATCH | `/api/trips/{tripId}` | 🔑 여행 수정 |
| | DELETE | `/api/trips/{tripId}` | 🔑 여행 삭제 |
| | POST | `/api/trips/join` | 초대 코드로 참여 (회원) |
| | POST | `/api/trips/join/guest` | 초대 코드로 참여 (게스트) |
| 멤버 | GET | `/api/trips/{tripId}/members` | 멤버 목록 |
| | DELETE | `/api/trips/{tripId}/members/me` | 여행 나가기 |
| | PATCH | `/api/trips/{tripId}/members/me/prepaid-rate` | 내 선불 환율 설정 |
| 준비 업무 | GET | `/api/trips/{tripId}/tasks` | 목록 |
| | POST | `/api/trips/{tripId}/tasks` | 추가 |
| | PATCH | `/api/trips/{tripId}/tasks/{taskId}` | 수정·완료 체크 |
| | DELETE | `/api/trips/{tripId}/tasks/{taskId}` | 삭제 |
| 일정 | GET | `/api/trips/{tripId}/schedules` | 목록 |
| | GET | `/api/trips/{tripId}/schedules/{scheduleId}` | 상세 |
| | POST | `/api/trips/{tripId}/schedules` | 추가 |
| | PATCH | `/api/trips/{tripId}/schedules/{scheduleId}` | 수정 |
| | DELETE | `/api/trips/{tripId}/schedules/{scheduleId}` | 삭제 |
| | PUT | `/api/trips/{tripId}/schedules/{scheduleId}/activity` | 활동 기록 (POST도 같음) |
| | DELETE | `/api/trips/{tripId}/schedules/{scheduleId}/activity` | 활동 기록 취소 |
| | GET | `/api/trips/{tripId}/today` | 오늘 요약 |
| 투표 | GET | `/api/trips/{tripId}/polls` | 목록 |
| | POST | `/api/trips/{tripId}/polls` | 만들기 |
| | GET | `/api/trips/{tripId}/polls/{pollId}` | 상세 (득표 수 포함) |
| | PUT | `/api/trips/{tripId}/polls/{pollId}/votes/me` | 투표·변경 |
| | DELETE | `/api/trips/{tripId}/polls/{pollId}/votes/me` | 투표 취소 |
| | POST | `/api/trips/{tripId}/polls/{pollId}/close` | 마감 + 일정 반영 |
| | DELETE | `/api/trips/{tripId}/polls/{pollId}` | 삭제 |
| 환율 | GET | `/api/exchange-rates` | 환율 조회 |
| 예산 | GET | `/api/trips/{tripId}/budget-items` | 예산 목록 + 카테고리별 사용액 |
| | POST | `/api/trips/{tripId}/budget-items` | 추가 |
| | PATCH | `/api/trips/{tripId}/budget-items/{budgetItemId}` | 수정 |
| | DELETE | `/api/trips/{tripId}/budget-items/{budgetItemId}` | 삭제 |
| 지출 | GET | `/api/trips/{tripId}/expenses` | 목록 (커서) |
| | POST | `/api/trips/{tripId}/expenses` | 추가 |
| | POST | `/api/trips/{tripId}/expenses/preview` | 추가 전 계산 (저장 안 함) |
| | GET | `/api/trips/{tripId}/expenses/{expenseId}` | 상세 |
| | PUT | `/api/trips/{tripId}/expenses/{expenseId}` | 수정 (전체 교체) |
| | DELETE | `/api/trips/{tripId}/expenses/{expenseId}` | 삭제 |
| 정산 | GET | `/api/trips/{tripId}/settlement` | 현재 정산 계산 결과 |
| | GET | `/api/trips/{tripId}/settlement/me` | 내 정산 · 계산 근거 |
| | POST | `/api/trips/{tripId}/settlement-shares` | 정산 결과 공유 (스냅샷 저장) |
| | GET | `/api/trips/{tripId}/settlement-shares` | 공유 이력 |
| | GET | `/api/trips/{tripId}/settlement-shares/{shareId}` | 공유 상세 |
| 알림 | GET | `/api/notifications` | 알림함 (커서) |
| | GET | `/api/notifications/unread-count` | 안 읽은 알림 수 |
| | PATCH | `/api/notifications/{notificationId}/read` | 읽음 처리 |
| | PATCH | `/api/notifications/read-all` | 모두 읽음 |
| | PUT | `/api/device-tokens` | FCM 토큰 등록·갱신 |
| | DELETE | `/api/device-tokens` | FCM 토큰 삭제 |

---

## 3. 인증 · 회원 ✅ 구현

### POST `/api/auth/signup` — 회원가입 (BP-AU-003)

인증 불필요. **가입하면 바로 로그인 상태**가 되도록 토큰을 함께 준다.

```json
{ "email": "user@example.com", "password": "backpack1234", "name": "홍길동" }
```

| 필드 | 규칙 |
|---|---|
| email | 필수, 이메일 형식, 최대 255자. 소문자로 바꿔 저장 |
| password | 필수, 8~64자, **영문과 숫자를 각각 1자 이상** |
| name | 필수, 1~20자 (앞뒤 공백 제거) |

`201 Created` — 로그인 응답과 같은 형식. 에러: `409 EMAIL_ALREADY_EXISTS`

### POST `/api/auth/login` — 로그인 (BP-AU-002)

인증 불필요. 이메일은 대소문자·앞뒤 공백을 구분하지 않는다.

```json
{ "email": "user@example.com", "password": "backpack1234" }
```

`200 OK`

```json
{
  "tokenType": "Bearer",
  "accessToken": "eyJ...",
  "accessTokenExpiresIn": 1800,
  "refreshToken": "q8Zx...",
  "user": { "id": "0192...", "email": "user@example.com", "name": "홍길동", "notifySchedule": true, "notifyExpense": true, "notifySettlement": true, "createdAt": "2026-10-12T03:00:00Z" }
}
```

| 에러 | 상황 |
|---|---|
| `401 INVALID_CREDENTIALS` | 이메일 없음 / 비밀번호 틀림 / 탈퇴 회원 (**구분하지 않는다**) |
| `429 TOO_MANY_LOGIN_ATTEMPTS` | 같은 이메일로 15분 안에 5번 틀림. 15분 뒤 풀린다 |

- 없는 이메일도 비밀번호 검사 시간을 똑같이 써서 응답 시간으로 가입 여부를 알 수 없다

### POST `/api/auth/reissue` — 토큰 재발급

인증 불필요. 리프레시 토큰은 한 번 쓰면 30초 뒤 무효가 되므로 **응답의 새 리프레시 토큰으로 꼭 바꿔 저장**한다.

```json
{ "refreshToken": "q8Zx..." }
```

`200 OK` — 로그인과 같은 형식. 에러: `401 UNAUTHORIZED` (다시 로그인)

### POST `/api/auth/logout` — 로그아웃

액세스 토큰 필요. 이 기기의 리프레시 토큰을 즉시 폐기한다.

```json
{ "refreshToken": "q8Zx..." }
```

`204 No Content`

### GET `/api/users/me` — 내 정보

`/api/me`도 같은 응답 (역할 분담 문서의 이름). `200 OK` — 로그인 응답의 `user`와 같은 형식

### PATCH `/api/users/me` — 이름 변경

```json
{ "name": "김철수" }
```

`200 OK` — 내 정보 형식

### PATCH `/api/users/me/password` — 비밀번호 변경

**다른 기기는 모두 로그아웃**되고, 지금 기기는 응답의 새 토큰으로 계속 쓴다.

```json
{ "currentPassword": "backpack1234", "newPassword": "newpass5678" }
```

`200 OK` — 로그인 응답 형식. 에러: `400 INVALID_PASSWORD` 현재 비밀번호 불일치

### PATCH `/api/users/me/notification-settings` — 알림 설정

보낸 필드만 바뀐다. `200 OK` — 내 정보 형식

```json
{ "notifySchedule": false, "notifyExpense": true, "notifySettlement": true }
```

### DELETE `/api/users/me` — 탈퇴

```json
{ "password": "backpack1234" }
```

`204 No Content`. 처리 내용:

- `deleted_at` 기록, 이메일 익명화(같은 이메일로 다시 가입 가능), 비밀번호로 로그인 불가, 모든 리프레시 토큰 폐기
- 참여 중인 여행에서 모두 나가고, 멤버 행의 `display_name`에 탈퇴 시점 이름을 남긴다 (지출·정산 기록 유지)
- 방장이던 여행은 **가장 먼저 참여한 다른 멤버**가 방장이 된다

에러: `400 INVALID_PASSWORD`

---

## 4. 여행 · 멤버 ✅ 구현

### 여행 상태 · D-day (응답 공통)

여행지 시간대(`timeZone`) 기준 오늘 날짜로 계산한다.

| 필드 | 설명 |
|---|---|
| `status` | `UPCOMING`(여행 전) / `LIVE`(여행 중) / `DONE`(여행 후) |
| `dDay` | 출발일까지 남은 날. `0`이면 출발일, 음수면 이미 출발 |
| `dayNo` | 여행 중이면 며칠째(1부터), 아니면 `null` |
| `nights` | 박 수 |

### POST `/api/trips` — 여행 만들기 (BP-TR-002)

만든 사람이 `HOST`가 되고, 초대 코드 8자리가 발급된다 (대문자+숫자, 헷갈리는 `0 O 1 I` 제외, 충돌하면 다시 뽑음).

```json
{
  "name": "오사카 먹방",
  "destination": "일본 오사카",
  "startDate": "2026-11-01",
  "endDate": "2026-11-04",
  "currencyCode": "JPY",
  "timeZone": "Asia/Tokyo"
}
```

| 필드 | 규칙 |
|---|---|
| name | 필수, 최대 50자 |
| destination | 필수, 최대 100자 |
| startDate / endDate | 필수, `endDate >= startDate`, 1년 이내 |
| currencyCode | 필수, ISO 4217 (소문자도 받음) |
| timeZone | 선택, IANA 시간대. 기본 `Asia/Seoul`. 일정 시각의 기준이 된다 |

`201 Created` — 여행 상세 형식

### GET `/api/trips` — 내 여행 목록 (BP-TR-001)

내가 현재 멤버인 여행. **여행 중 → 다가오는 여행(가까운 순) → 지난 여행(최근 순)**.

```json
[
  {
    "id": "0192...",
    "name": "오사카 먹방",
    "destination": "일본 오사카",
    "startDate": "2026-11-01",
    "endDate": "2026-11-04",
    "currencyCode": "JPY",
    "status": "UPCOMING",
    "dDay": 8,
    "dayNo": null,
    "memberCount": 4,
    "myRole": "HOST"
  }
]
```

### GET `/api/trips/{tripId}` — 여행 상세 (BP-HM-001 · HM-002)

```json
{
  "id": "0192...",
  "name": "오사카 먹방",
  "destination": "일본 오사카",
  "startDate": "2026-11-01",
  "endDate": "2026-11-04",
  "nights": 3,
  "currencyCode": "JPY",
  "timeZone": "Asia/Tokyo",
  "inviteCode": "A7K2M9QX",
  "status": "UPCOMING",
  "dDay": 8,
  "dayNo": null,
  "myMemberId": "0192...",
  "myRole": "HOST",
  "memberCount": 2,
  "members": [
    { "memberId": "0192...", "name": "홍길동", "role": "HOST", "isMe": true, "prepaidRate": null, "joinedAt": "2026-10-12T03:00:00Z" }
  ],
  "createdAt": "2026-10-12T03:00:00Z"
}
```

에러: `403 NOT_TRIP_MEMBER` (여행이 없어도 같은 응답)

### PATCH `/api/trips/{tripId}` 🔑 — 여행 수정

`name`, `destination`, `startDate`, `endDate`, `currencyCode`, `timeZone` 중 보낸 필드만 바뀐다.

| 에러 | 상황 |
|---|---|
| `409 TRIP_PERIOD_CONFLICT` | 바꿀 기간 밖에 일정이 있음. `details.scheduleCount`에 개수 |
| `409 TRIP_CURRENCY_LOCKED` | 지출이 있는 여행의 통화 변경 |

### DELETE `/api/trips/{tripId}` 🔑 — 여행 삭제

멤버·일정·지출·정산 등 하위 데이터가 모두 삭제된다(DB `ON DELETE CASCADE`). `204 No Content`

### POST `/api/trips/join` — 초대 코드로 참여 (BP-TR-003)

```json
{ "inviteCode": "a7k2-m9qx" }
```

- 소문자·공백·하이픈은 서버가 정리한다
- 이미 멤버면 `200`과 함께 그 여행을 그대로 돌려준다
- 나갔던 여행이면 **같은 멤버 행을 되살린다** (나가기 전 지출·정산이 그대로 이어진다). 역할은 `MEMBER`

`200 OK` — 여행 상세 형식. 에러: `404 INVITE_CODE_NOT_FOUND` (시안의 빨간 테두리) / `409 TRIP_FULL` (30명)

### GET `/api/trips/{tripId}/members` — 멤버 목록

현재 멤버만, 참여 순. `200 OK` — 여행 상세의 `members`와 같은 형식

### DELETE `/api/trips/{tripId}/members/me` — 나가기

`left_at`만 기록한다(지출·정산 기록 유지). **방장이 나가면 가장 먼저 참여한 멤버가 방장**이 된다. `204 No Content`

### PATCH `/api/trips/{tripId}/members/me/prepaid-rate` — 내 선불 환율

환전해 간 환율 (여행 통화 1단위 → 원). 지출의 `rateMode = PREPAID`에서 쓴다. `null`이면 해제.

```json
{ "prepaidRate": 9.12 }
```

`200 OK` — 멤버 한 명 형식

> ⏳ 게스트 참여(`POST /api/trips/join/guest`)는 아직 구현하지 않았다 (BP-TR-004, 발표 이후).

---

## 5. 준비 업무 ✅ 구현

- `TEAM`(함께 할 업무): 멤버 모두가 보고 체크한다. 담당자를 정하면 그 사람에게 `TASK_ASSIGNED` 알림
- `PRIVATE`(개인 준비물): 만든 사람만 보고 고친다. 담당자는 항상 만든 사람. 남의 개인 업무는 `404 TASK_NOT_FOUND`

### GET `/api/trips/{tripId}/tasks?scope=TEAM`

| 쿼리 | 설명 |
|---|---|
| scope | `PRIVATE` / `TEAM`. 생략하면 내가 볼 수 있는 업무 전부 |

`200 OK` — 안 한 일 먼저, 그 안에서 마감이 빠른 순 (마감일 없는 업무는 뒤), 같으면 만든 순서

```json
[
  {
    "id": "0192...",
    "scope": "TEAM",
    "title": "숙소 예약",
    "dueDate": "2026-09-30",
    "status": "IN_PROGRESS",
    "isDone": false,
    "creator": { "memberId": "0192...", "name": "홍길동" },
    "assignee": { "memberId": "0192...", "name": "김철수" },
    "isMine": true,
    "createdAt": "2026-10-12T03:00:00Z"
  }
]
```

- `assignee`: 담당자가 없으면 `null`
- `dueDate`: 마감일. 없으면 `null` (V3 마이그레이션)
- `status`: `TODO`(할 일) · `IN_PROGRESS`(진행 중) · `DONE`(완료). `isDone`은 `status == DONE`과 같다
- `isMine`: 내가 만들었거나 내가 맡은 업무

### POST `/api/trips/{tripId}/tasks`

```json
{ "scope": "TEAM", "title": "숙소 예약", "assigneeMemberId": "0192...", "dueDate": "2026-09-30", "status": "TODO" }
```

| 필드 | 규칙 |
|---|---|
| scope | 필수 |
| title | 필수, 최대 100자 |
| assigneeMemberId | 선택. 이 여행의 현재 멤버. `PRIVATE`이면 무시 |
| dueDate | 선택. 앱은 함께 할 업무에서 담당자와 함께 필수로 받는다 (스토리보드 BP-PR-002) |
| status | 선택, 기본 `TODO` |

`201 Created` — 목록 항목 형식

### PATCH `/api/trips/{tripId}/tasks/{taskId}`

```json
{ "title": "숙소 예약 (2박)", "assigneeMemberId": "0192...", "dueDate": "2026-10-01", "status": "IN_PROGRESS" }
```

보낸 필드만 바뀐다. 담당자 · 마감일을 비우려면 `clearAssignee: true` · `clearDueDate: true`.
진행 상태(`status`)와 체크(`isDone`)는 볼 수 있는 사람 누구나 바꿀 수 있다. 둘 다 보내면 `status`가 이긴다. `isDone: false`는 할 일(`TODO`)로 되돌린다.

`200 OK` — 목록 항목 형식

### DELETE `/api/trips/{tripId}/tasks/{taskId}`

개인 업무는 만든 사람, 함께 할 업무는 만든 사람 · 담당자 · 방장. 아니면 `403 NOT_TASK_OWNER`

`204 No Content`

---

## 6. 일정 · 활동 기록 · 오늘 요약 ✅ 구현

시각은 모두 **여행지 현지 기준** `HH:mm` (여행의 `timeZone`). 초는 버린다.

### 규칙

| 규칙 | 에러 |
|---|---|
| `endTime > startTime` (자정을 넘는 일정은 두 개로 나눈다) | `400 INVALID_TIME_RANGE` |
| `day`는 여행 기간 안 | `400 SCHEDULE_OUT_OF_TRIP` |
| 같은 날 `new.start < old.end AND new.end > old.start`인 일정이 있으면 거부. 끝나는 시각에 시작하는 것은 괜찮다 | `409 SCHEDULE_OVERLAP` |
| 고정된(`isLocked`) 일정은 고정을 먼저 풀어야 고치거나 지울 수 있다 | `409 SCHEDULE_LOCKED` |
| 수정 요청의 `version`이 현재 값과 다르면 거부 | `409 VERSION_CONFLICT` |

`SCHEDULE_OVERLAP`의 `details` — 시안의 "겹친 일정 표시"에 쓴다:

```json
{ "scheduleId": "0192...", "title": "구로몬 시장", "day": "2026-10-03", "startTime": "12:00", "endTime": "13:30", "overlapCount": "1" }
```

### GET `/api/trips/{tripId}/schedules?day=2026-11-01` (BP-SC-001)

`day` 생략 시 전체. 날짜 → 시작 시각순.

```json
[
  {
    "id": "0192...",
    "day": "2026-11-01",
    "startTime": "12:00",
    "endTime": "13:30",
    "title": "점심",
    "placeText": "이치란 도톤보리점",
    "isLocked": false,
    "reservationStatus": "CONFIRMED",
    "memo": "대기 30분",
    "status": "DONE",
    "activity": { "actualStartTime": "12:05", "actualEndTime": "13:50", "delayMin": 20, "recordedBy": { "memberId": "0192...", "name": "홍길동" } },
    "createdBy": { "memberId": "0192...", "name": "홍길동" },
    "version": 3,
    "updatedAt": "2026-10-12T03:00:00Z"
  }
]
```

- `status`: `PLANNED` / `IN_PROGRESS`(지금 시간대 안) / `DONE`(활동 기록 있음). 저장하지 않고 계산한다
- `activity`: 활동 기록이 없으면 `null`

### GET `/api/trips/{tripId}/schedules/{scheduleId}`

`200 OK` — 목록 항목 형식. 에러: `404 SCHEDULE_NOT_FOUND`

### POST `/api/trips/{tripId}/schedules` (BP-SC-002)

```json
{
  "day": "2026-11-01",
  "startTime": "12:00",
  "endTime": "13:30",
  "title": "점심",
  "placeText": "이치란 도톤보리점",
  "reservationStatus": "NONE",
  "memo": null,
  "isLocked": false
}
```

| 필드 | 규칙 |
|---|---|
| day / startTime / endTime | 필수 |
| title | 필수, 최대 100자 |
| placeText | 선택, 최대 100자 |
| reservationStatus | 선택, 기본 `NONE` |
| memo | 선택, 최대 500자 |
| isLocked | 선택, 기본 `false` |

`201 Created` — 목록 항목 형식

### PATCH `/api/trips/{tripId}/schedules/{scheduleId}`

`version` 필수, 나머지는 보낸 필드만 바뀐다. `placeText`·`memo`는 `""`를 보내면 지워진다.

```json
{ "version": 3, "startTime": "12:30", "isLocked": true }
```

- 고정된 일정에 허용하는 요청은 `{ "version": n, "isLocked": false }` (고정 풀기) 하나뿐이다
- 시간을 바꿀 때도 겹침을 검사한다 (자기 자신은 제외)

`200 OK` — 목록 항목 형식 (`version`이 올라간 값)

### DELETE `/api/trips/{tripId}/schedules/{scheduleId}` (BP-SC-003)

고정된 일정은 `409 SCHEDULE_LOCKED`. 활동 기록도 함께 지워진다. `204 No Content`

### PUT `/api/trips/{tripId}/schedules/{scheduleId}/activity` — 활동 기록 (BP-AI-004)

`POST`도 같다(역할 분담 문서의 이름). 다시 기록하면 덮어쓴다. 고정 여부와 상관없이 기록할 수 있다.

```json
{ "actualStartTime": "12:05", "actualEndTime": "13:20" }
```

- `delayMin = max(0, 실제 종료 − 계획 종료)` (분)
- 기록이 있으면 그 일정은 `DONE`

`200 OK` — 목록 항목 형식. 에러: `400 INVALID_TIME_RANGE` 실제 종료 < 실제 시작

### DELETE `/api/trips/{tripId}/schedules/{scheduleId}/activity` — 기록 취소

`204 No Content`

### GET `/api/trips/{tripId}/today` — 오늘 요약 (BP-AI-001 · HM-001 여행 중)

```json
{
  "date": "2026-10-03",
  "localTime": "14:50",
  "timeZone": "Asia/Tokyo",
  "now": "2026-10-03T05:50:00Z",
  "tripStatus": "LIVE",
  "dayNo": 2,
  "current": { "title": "도톤보리", "status": "IN_PROGRESS", "...": "일정 형식" },
  "next": { "title": "숙소 휴식", "...": "일정 형식" },
  "nextFixed": { "schedule": { "title": "저녁 예약", "...": "일정 형식" }, "minutesUntil": 190 },
  "delayMin": 45,
  "doneCount": 1,
  "total": 5,
  "remaining": 4,
  "schedules": [ "오늘 일정 전체 (일정 형식)" ]
}
```

| 필드 | 설명 |
|---|---|
| `current` | 지금 시간대에 걸친, 아직 완료 기록이 없는 일정. 없으면 `null` |
| `next` | 아직 시작하지 않은 다음 일정 |
| `nextFixed` | 다음 **고정** 일정과 남은 시간(분). 시안의 "다음 고정 일정까지" |
| `delayMin` | 오늘 활동 기록의 지연 합계. 시안의 "45분 지연" 배너 |

> 시연 때는 서버 설정 `APP_DEMO_NOW=2026-10-03T05:50:00Z`로 "지금"을 고정할 수 있다 (도쿄 14:50).

---

## 7. 장소 투표 ✅ 구현

1인 1표. 만든 사람이나 방장이 마감하면서 후보를 고르면 그 후보 이름으로 슬롯 시간에 일정을 만든다 (일정 추가와 같은 기간 · 겹침 검사). 투표를 만들면 `POLL_CREATED`, 마감하면 `POLL_CLOSED` 알림이 간다 (`notifySchedule`).

### GET `/api/trips/{tripId}/polls?status=OPEN`

`status`(`OPEN` / `CLOSED`)를 생략하면 전체. 최신순. 항목은 **상세와 같은 형식**이다 (여행 인원이 적어 후보 · 투표자를 함께 내려도 가볍다).

`200 OK` — 상세 형식의 배열

### POST `/api/trips/{tripId}/polls`

```json
{
  "title": "둘째 날 저녁",
  "slotDate": "2026-11-02",
  "slotStart": "18:00",
  "slotEnd": "20:00",
  "deadlineAt": "2026-10-30T12:00:00Z",
  "options": [
    { "label": "야키니쿠 A", "memo": "도보 5분" },
    { "label": "오코노미야키 B", "memo": null }
  ]
}
```

| 필드 | 규칙 |
|---|---|
| title | 필수, 최대 100자 |
| slotDate | 필수, 여행 기간 안 (`400 SCHEDULE_OUT_OF_TRIP`) |
| slotStart / slotEnd | 필수, 여행지 현지 시각, `slotEnd > slotStart` (`400 INVALID_TIME_RANGE`). 이미 있는 일정과 겹치면 `409 SCHEDULE_OVERLAP` (스토리보드 BP-VT-002 ⑧) |
| deadlineAt | 선택, 지금 이후. 지나면 투표만 막히고(`409 POLL_CLOSED`) 마감은 사람이 한다 |
| options | 필수, 2~6개, 같은 이름 중복 불가. 보낸 순서대로 `sortOrder` 1~6 |
| options[].label | 필수, 최대 100자 |
| options[].memo | 선택, 최대 255자 |

`201 Created` — 상세 형식

### GET `/api/trips/{tripId}/polls/{pollId}`

`200 OK`

```json
{
  "id": "0192...",
  "title": "둘째 날 저녁",
  "slotDate": "2026-11-02",
  "slotStart": "18:00",
  "slotEnd": "20:00",
  "deadlineAt": "2026-10-30T12:00:00Z",
  "status": "OPEN",
  "isVotingOpen": true,
  "creator": { "memberId": "0192...", "name": "홍길동" },
  "canManage": true,
  "options": [
    {
      "id": "0192...", "label": "야키니쿠 A", "memo": "도보 5분", "sortOrder": 1,
      "voteCount": 2, "isLeading": true,
      "voters": [{ "memberId": "0192...", "name": "홍길동" }, { "memberId": "0192...", "name": "김철수" }]
    },
    { "id": "0192...", "label": "오코노미야키 B", "memo": null, "sortOrder": 2, "voteCount": 0, "isLeading": false, "voters": [] }
  ],
  "voteCount": 2,
  "memberCount": 3,
  "myOptionId": "0192...",
  "selectedOptionId": null,
  "scheduleId": null,
  "createdAt": "2026-10-12T03:00:00Z",
  "closedAt": null
}
```

- `isVotingOpen`: `OPEN`이고 마감 시각이 지나지 않았을 때만 `true`
- `canManage`: 마감 · 삭제 버튼을 보여 줄지 (만든 사람 · 방장)
- `isLeading`: 가장 많이 받은 후보. 동점이면 모두 `true`, 0표면 `false`
- `voteCount` / `memberCount`: "2/3명 참여"

### PUT `/api/trips/{tripId}/polls/{pollId}/votes/me` — 투표·변경

이미 투표했으면 후보만 바꾼다.

```json
{ "optionId": "0192..." }
```

`200 OK` — 상세 형식. 에러: `400 INVALID_POLL_OPTION` 다른 투표의 후보 / `409 POLL_CLOSED`

### DELETE `/api/trips/{tripId}/polls/{pollId}/votes/me` — 투표 취소

`204 No Content`. 에러: `409 POLL_CLOSED`

### POST `/api/trips/{tripId}/polls/{pollId}/close` — 마감

만든 사람 · 방장만 (`403 NOT_POLL_MANAGER`). `selectedOptionId`를 보내면 그 후보로 일정을 만들고 `scheduleId`에 연결한다. 생략하면 일정 없이 마감만 한다.

```json
{ "selectedOptionId": "0192..." }
```

`200 OK` — 상세 형식 (`status: CLOSED`). 에러: `409 POLL_CLOSED` 이미 마감 / `409 SCHEDULE_OVERLAP` 슬롯에 다른 일정이 있음 (투표는 열린 채로 남는다)

### DELETE `/api/trips/{tripId}/polls/{pollId}`

만든 사람 · 방장만. 반영된 일정은 남는다. `204 No Content`

---

## 8. 환율 · 예산

### GET `/api/exchange-rates?currencyCode=JPY&date=2026-11-01` ✅ 구현

통화 1단위 → KRW. `exchange_rates`에 그 날짜 값이 없으면 서버가 외부 API에서 바로 받아 저장한 뒤 돌려준다. 그래도 그 날짜 값이 없으면(주말 · 공휴일 · 수집 실패) **가장 가까운 이전 날짜 값**을 주고 `rateDate`에 실제 날짜, `isFallback: true`를 담는다. 미래 날짜는 오늘 환율로 계산한다.

환율 수집 (`budget/service/rate`)

| 순서 | 출처 | 비고 |
|---|---|---|
| 1 | 한국수출입은행 현재환율 API | `EXIM_API_KEY`가 있을 때만. 매매기준율, `JPY(100)`처럼 100단위 값은 100으로 나눈다 |
| 2 | Frankfurter (유럽중앙은행 기준) | 키 없음. 날짜 지정 가능, 주말이면 직전 영업일 값 |
| 3 | ExchangeRate-API (open.er-api.com) | 키 없음. 오늘 값만 (VND처럼 ECB가 주지 않는 통화) |

- 앞 출처가 실패하면 다음 출처를 쓴다. 같은 통화 · 날짜를 받지 못하면 30분, 이전 날짜 값만 받았으면 3시간 동안 다시 부르지 않는다
- 2시간마다(한국 시각 매 짝수 시 20분) 기본 통화(`exchange-rate.default-currencies`, 기본 `JPY,USD,EUR`)와, 끝난 지 14일이 안 된 여행 · 진행 중 · 다가오는 여행의 통화를 오늘 날짜로 미리 받아 둔다
- `EXCHANGE_RATE_FETCH_ENABLED=false`면 외부를 부르지 않고 쌓인 값만 쓴다 (테스트)

| 쿼리 | 설명 |
|---|---|
| currencyCode | 필수. 영문 3자리, 소문자도 받는다. 역할 분담 문서의 이름 `currency`도 같은 뜻으로 받는다 |
| date | 선택, 기본 오늘(한국 날짜) |

`200 OK`

```json
{
  "currencyCode": "JPY",
  "requestedDate": "2026-10-04",
  "rateDate": "2026-10-03",
  "rateToKrw": 9.350000,
  "unit": 100,
  "unitRateToKrw": 935.00,
  "fetchedAt": "2026-10-03T00:00:00Z",
  "isFallback": true
}
```

- `unit` / `unitRateToKrw`: 화면 표시용. JPY·IDR·VND는 100단위(`100엔 = 935.00원`), 나머지는 1단위
- `fetchedAt`: 값을 저장한 시각 (화면의 "10.03 09:00 기준")
- `KRW`는 항상 1

에러: `400 VALIDATION_ERROR` 통화 코드 형식 / `404 EXCHANGE_RATE_NOT_FOUND` 그 날짜 이전 값이 하나도 없음

### GET `/api/trips/{tripId}/budget-items` ✅ 구현

예산 항목과 분류별 합계(예산 vs 실제 지출, 원화). 여행 통화로 넣은 예산은 **오늘 환율**로 원화 환산한다.

`200 OK`

```json
{
  "items": [
    { "id": "0192...", "category": "LODGING", "name": "호텔 3박", "amount": 450000, "currencyCode": "KRW", "amountKrw": 450000, "createdAt": "2026-10-12T03:00:00Z" },
    { "id": "0192...", "category": "FOOD", "name": "식비", "amount": 30000, "currencyCode": "JPY", "amountKrw": 253398, "createdAt": "2026-10-12T03:00:00Z" }
  ],
  "summary": [
    { "category": "FOOD", "budgetKrw": 253398, "spentKrw": 40966 },
    { "category": "LODGING", "budgetKrw": 450000, "spentKrw": 0 }
  ],
  "totalBudgetKrw": 703398,
  "totalSpentKrw": 40966,
  "memberCount": 2,
  "perPersonBudgetKrw": 351699,
  "currencyCode": "JPY",
  "todayRate": { "currencyCode": "JPY", "rateToKrw": 8.446600, "unit": 100, "unitRateToKrw": 844.66 },
  "hasUnconvertedItems": false
}
```

- `summary`: 예산이 있거나 지출이 있는 분류만. 지출은 지출의 원화 금액(`amountKrw`) 합
- `perPersonBudgetKrw`: 1인 준비 금액 = 전체 예산 ÷ 현재 멤버 수 (원 단위 올림)
- `todayRate`: 여행 통화의 오늘 환율 (환율 조회 형식). 원화 여행이거나 환율을 모르면 `null`
- `hasUnconvertedItems`: 환율을 몰라 원화로 바꾸지 못한 항목이 있음 (그 항목은 `amountKrw: null`, 합계에서 빠진다)

### POST `/api/trips/{tripId}/budget-items` ✅ 구현

```json
{ "category": "FOOD", "name": "식비", "amount": 30000, "currencyCode": "JPY" }
```

| 필드 | 규칙 |
|---|---|
| category | 필수, 카테고리 코드 |
| name | 필수, 최대 100자 |
| amount | 필수, 0 이상, 소수 둘째 자리까지 |
| currencyCode | 필수, `KRW` 또는 여행 통화 |

`201 Created` — 항목 형식

### PATCH `/api/trips/{tripId}/budget-items/{budgetItemId}` ✅ 구현

보낸 필드만 바뀐다. 멤버 누구나. `200 OK` — 항목 형식

### DELETE `/api/trips/{tripId}/budget-items/{budgetItemId}` ✅ 구현

`204 No Content`

---

## 9. 지출

### 계산 규칙 (서버 기준, 앱은 직접 계산하지 않는다)

| 규칙 | 내용 |
|---|---|
| 원화 환산 | `amountKrw = round(amountLocal × 환율)`, 0.5원은 올림. KRW 입력이면 그대로 |
| 환율 스냅샷 | 등록 시점의 환율을 `appliedRate`에 저장한다. 나중에 환율이 바뀌어도 지난 지출은 변하지 않는다 |
| 균등 분담 | 1인 몫 = `floor(금액 / n)`. 남는 원(끝전)은 **결제자**가 부담. 결제자가 분담 대상이 아니면 **대상 목록의 첫 번째 사람** |
| 항목별 금액 | 항목마다 내림한 뒤 모자란 원을 소수점 아래가 큰 항목부터 1원씩 채운다 → 항목 합계 = 총액 |
| 검증 | 저장 전에 `Σ분담액 == amountKrw`를 확인한다 |

> ⚠️ 시안 JS는 `Math.round(amount / n)` 후 차액을 결제자에게 몰아준다. 결과가 1~4원 다를 수 있으므로 앱은 **`POST /expenses/preview` 응답을 그대로 보여 준다.**

### GET `/api/trips/{tripId}/expenses` ✅ 구현 — 목록 + 공동 지출 합계

| 쿼리 | 설명 |
|---|---|
| date | 선택, `paidDate` 필터 |
| category | 선택 (`FOOD`, `LODGING`, `TRANSPORT`, `ACTIVITY`, `SHOPPING`, `ETC`) |
| cursor / size | 커서 페이지. 결제일 최신순, 같은 날은 최근 등록순. `size` 기본 20, 최대 100 |

`200 OK`

```json
{
  "content": [
    {
      "id": "0192...",
      "title": "구로몬 시장",
      "category": "FOOD",
      "paidDate": "2026-10-03",
      "rateMode": "API",
      "amountLocal": 4850.00,
      "amountKrw": 45348,
      "payer": { "memberId": "0192...", "name": "박멤버" },
      "creator": { "memberId": "0192...", "name": "김방장" },
      "isPaidByMe": false,
      "myShareKrw": 9069,
      "createdAt": "2026-10-03T05:50:00Z"
    }
  ],
  "nextCursor": "2026-10-03_0192...",
  "hasNext": true,
  "summary": {
    "count": 12,
    "totalKrw": 813899,
    "currencyCode": "JPY",
    "todayRate": { "currencyCode": "JPY", "rateToKrw": 9.350000, "unit": 100, "unitRateToKrw": 935.00, "...": "환율 조회와 같은 형식" },
    "byCategory": [
      { "category": "FOOD", "amountKrw": 412000 },
      { "category": "LODGING", "amountKrw": 300000 }
    ]
  }
}
```

- `creator`가 `payer`와 다르면 다른 사람이 대신 입력한 지출 (목록의 "대리 입력" 배지)
- `summary`는 페이지와 상관없이 필터에 맞는 **전체** 지출의 건수·합계 (화면 상단 "공동 지출 · N건")
- `todayRate`는 여행 통화의 오늘 환율. 여행 통화가 KRW이거나 환율이 없으면 `null`
- `byCategory`는 필터와 상관없이 여행 전체 지출의 분류별 원화 합계, 금액이 큰 순 (분류 비율 막대)

### POST `/api/trips/{tripId}/expenses` ✅ 구현 — 등록

```json
{
  "payerMemberId": "0192...",
  "title": "구로몬 시장",
  "category": "FOOD",
  "paidDate": "2026-10-03",
  "rateMode": "API",
  "amountLocal": 4850,
  "manualRate": null,
  "amountKrw": null,
  "splitMethod": "EQUAL",
  "memberIds": ["0192...", "0192...", "0192...", "0192...", "0192..."]
}
```

**환율 모드(`rateMode`)**

| 값 | 필요한 값 | 적용 환율 |
|---|---|---|
| `API` | `amountLocal` | `paidDate`의 환율, 없으면 이전 날짜 값 (`rateDate`에 실제 날짜) |
| `PREPAID` | `amountLocal` | 결제자의 `prepaidRate`. 없으면 `400 PREPAID_RATE_NOT_SET` |
| `MANUAL` | `amountLocal`, `manualRate` | 입력한 환율 |
| `KRW` | `amountKrw` | 없음. `amountLocal`·`manualRate`를 보내면 `400` |

여행 통화가 KRW인 여행은 `KRW` 모드만 쓸 수 있다.

**분담 방식(`splitMethod`)**

| 값 | 보내는 것 |
|---|---|
| `EQUAL` | `memberIds`(분담자 목록) **또는** 항목 1개짜리 `items`. N분의 1 + 끝전 |
| `ITEM` | `items` 여러 개. 항목마다 금액(`amountLocal`, KRW 모드면 `amountKrw`)과 `members`. 항목 금액 합계 = 총액 |
| `CUSTOM` | 항목 1개. `members[].shareKrw`로 사람별 금액, 합계 = 총액 |

```json
"items": [
  { "name": "라멘 A", "amountLocal": 1200, "members": [ { "memberId": "0192..." } ] },
  { "name": "라멘 B + 맥주", "amountLocal": 3650, "members": [ { "memberId": "0192..." }, { "memberId": "0192..." } ] }
]
```

공통 규칙

- `payerMemberId`, 분담자는 이 여행의 **현재 멤버**
- 같은 항목에 같은 사람을 두 번 넣을 수 없다
- 대리 입력: 요청한 사람이 `creator`, `payerMemberId`가 결제자

`201 Created` — 상세 형식

```json
{
  "id": "0192...",
  "title": "구로몬 시장",
  "category": "FOOD",
  "paidDate": "2026-10-03",
  "currencyCode": "JPY",
  "rateMode": "API",
  "amountLocal": 4850.00,
  "appliedRate": 9.350000,
  "rateDate": "2026-10-03",
  "amountKrw": 45348,
  "splitMethod": "EQUAL",
  "payer": { "memberId": "0192...", "name": "박멤버" },
  "creator": { "memberId": "0192...", "name": "김방장" },
  "items": [
    {
      "id": "0192...",
      "name": "총액",
      "amountLocal": 4850.00,
      "amountKrw": 45348,
      "sortOrder": 1,
      "remainderKrw": 3,
      "remainderMember": { "memberId": "0192...", "name": "박멤버" },
      "members": [ { "memberId": "0192...", "name": "김방장", "shareKrw": 9069 } ]
    }
  ],
  "memberShares": [
    { "memberId": "0192...", "name": "박멤버", "shareKrw": 9072, "shareLocal": 970.27, "isPayer": true }
  ],
  "version": 0,
  "createdAt": "2026-10-03T05:50:00Z",
  "updatedAt": "2026-10-03T05:50:00Z"
}
```

- `remainderKrw` / `remainderMember`: 끝전과 부담한 사람 (시안의 "원 단위 끝전은 결제자 부담")
- `memberShares`: 사람별 부담 합계(등록 완료 화면의 "개인별 부담"). `shareLocal`은 표시용 외화 환산값

에러

| code | 상황 |
|---|---|
| `400 VALIDATION_ERROR` | 필수값 누락·형식 오류. `details`에 필드별 메시지 |
| `400 INVALID_EXPENSE` | 금액·분담 규칙 위반. `details`의 키가 문제의 위치 (예: `items[0].members[1].memberId`) |
| `400 PREPAID_RATE_NOT_SET` | 결제자의 선불 환율 없음 |
| `404 EXCHANGE_RATE_NOT_FOUND` | `API` 모드인데 환율이 하나도 없음 |
| `403 NOT_TRIP_MEMBER` | 여행 멤버가 아님 |

### POST `/api/trips/{tripId}/expenses/preview` ✅ 구현 — 미리보기

등록과 같은 바디. **저장하지 않고** 계산 결과만 돌려준다. 지출 입력 ①(원화 환산)과 ②(분담·끝전) 화면에서 쓴다.

`200 OK` — 상세 형식에서 `id`, `version`, `createdAt`, `updatedAt`, `items[].id`가 `null`

### GET `/api/trips/{tripId}/expenses/{expenseId}` ✅ 구현 — 상세 (BP-EX-005)

`200 OK` — 등록 응답과 같은 상세 형식. 에러: `404 EXPENSE_NOT_FOUND`

### PUT `/api/trips/{tripId}/expenses/{expenseId}` ✅ 구현 — 수정 (전체 교체)

등록과 같은 바디 + `version`(조회 때 받은 값). 항목·분담자를 통째로 교체한다.

- **결제자 · 작성자 · 방장만** 수정할 수 있다 → 아니면 `403 NOT_EXPENSE_EDITOR`
- `API` 모드에서 결제일이 그대로면 등록 때 적용한 환율을 유지한다 (나중에 환율 값이 보정돼도 금액이 바뀌지 않게)
- 작성자(`creator`)는 바뀌지 않는다

`200 OK` — 상세 형식 (`version` + 1). 에러: `409 VERSION_CONFLICT` 그 사이 다른 사람이 수정

### DELETE `/api/trips/{tripId}/expenses/{expenseId}` ✅ 구현

결제자 · 작성자 · 방장만. `204 No Content`

---

## 10. 정산

정산은 저장하지 않고 요청 때마다 지출에서 계산한다. "공유"할 때만 그 시점의 송금 목록을 저장한다.

### GET `/api/trips/{tripId}/settlement` ✅ 구현 — 최종 정산 · 송금 경로

`200 OK`

```json
{
  "totalKrw": 813899,
  "expenseCount": 12,
  "transferTotalKrw": 285000,
  "directTransferCount": 14,
  "members": [
    {
      "memberId": "0192...",
      "name": "김방장",
      "isMe": true,
      "hasLeft": false,
      "paidKrw": 500000,
      "shareKrw": 215000,
      "balanceKrw": 285000,
      "status": "RECEIVE"
    }
  ],
  "transfers": [
    { "from": { "memberId": "0192...", "name": "이멤버" }, "to": { "memberId": "0192...", "name": "김방장" }, "amountKrw": 95000 }
  ],
  "calculatedAt": "2026-10-03T05:50:00Z"
}
```

- `balanceKrw = paidKrw − shareKrw`. `status`는 `RECEIVE`(받을 돈) / `SEND`(보낼 돈) / `SETTLED`
- `members`: 현재 멤버 전원(참여 순) + 지출 기록이 남은 나간 멤버(`hasLeft: true`)
- `transfers`: 받을 사람과 보낼 사람을 금액 큰 순으로 짝짓는다. 금액이 딱 맞는 쌍은 먼저 짝지어 건수를 줄인다. 최대 (인원 − 1)건
- `transferTotalKrw`는 양수 잔액의 합과 항상 같다 (서버가 검증)
- `directTransferCount`: 지출마다 각자 결제자에게 바로 보낸다면 필요한 송금 건수 (보내는 사람 → 받는 사람 쌍). 화면의 "송금 14건 → 4건으로 줄였어요"

### GET `/api/trips/{tripId}/settlement/me` ✅ 구현 — 내 정산 · 계산 근거

계산 근거 화면(BP-ST-002)과 홈의 "공동 지출 · 지금까지 내 정산" 카드에 쓴다.

`200 OK`

```json
{
  "me": { "memberId": "0192...", "name": "이멤버" },
  "paidKrw": 12000,
  "shareKrw": 25069,
  "balanceKrw": -13069,
  "status": "SEND",
  "tripTotalKrw": 87348,
  "expenseCount": 3,
  "transfers": [
    { "direction": "SEND", "counterpart": { "memberId": "0192...", "name": "박멤버" }, "amountKrw": 11207 }
  ],
  "expenses": [
    {
      "expenseId": "0192...",
      "title": "구로몬 시장",
      "category": "FOOD",
      "paidDate": "2026-10-04",
      "amountKrw": 45348,
      "payer": { "memberId": "0192...", "name": "박멤버" },
      "isPaidByMe": false,
      "paidKrw": 0,
      "myShareKrw": 9069,
      "balanceKrw": -9069
    }
  ],
  "calculatedAt": "2026-10-03T05:50:00Z"
}
```

- `expenses`: 내가 결제했거나 분담한 지출만, 결제일 최신순. `balanceKrw`를 모두 더하면 위의 `balanceKrw`와 같다
- `transfers`: 전체 송금 경로 중 나와 관련된 것만

### POST `/api/trips/{tripId}/settlement-shares` ✅ 구현 — 정산 결과 공유 (BP-ST-003)

지금 계산한 `transfers`를 그대로 저장한다. 이후 지출이 바뀌어도 공유한 목록은 바뀌지 않는다 ("그때 이렇게 보내기로 했다"). 바디 없음.

`201 Created`

```json
{
  "id": "0192...",
  "sharedBy": { "memberId": "0192...", "name": "홍길동" },
  "createdAt": "2026-11-05T03:00:00Z",
  "transferTotalKrw": 285000,
  "transfers": [
    { "id": "0192...", "from": { "memberId": "0192...", "name": "김철수" }, "to": { "memberId": "0192...", "name": "홍길동" }, "amountKrw": 95000 }
  ]
}
```

에러: `409 NOTHING_TO_SETTLE` 주고받을 돈이 없음

> ⏳ 공유 시 멤버 푸시 알림(`SETTLEMENT_SHARED`)은 알림 기능과 함께 붙인다.

### GET `/api/trips/{tripId}/settlement-shares` ✅ 구현 — 공유 이력

최신순.

```json
[ { "id": "0192...", "sharedBy": { "memberId": "0192...", "name": "홍길동" }, "createdAt": "2026-11-05T03:00:00Z", "transferCount": 3, "transferTotalKrw": 285000 } ]
```

### GET `/api/trips/{tripId}/settlement-shares/{shareId}` ✅ 구현 — 공유 상세

`200 OK` — 공유 응답과 같은 형식. 에러: `404 SETTLEMENT_SHARE_NOT_FOUND`

---

## 11. 알림 ✅ 구현

### GET `/api/notifications?cursor=&size=20` — 알림함

내 알림(회원은 `user_id`, 게스트는 `member_id`). 최신순, 커서 페이지.

```json
{
  "content": [
    {
      "id": "0192...",
      "tripId": "0192...",
      "tripName": "오사카 먹방",
      "type": "EXPENSE_ADDED",
      "message": "홍길동님이 '이치란' 지출을 추가했어요.",
      "refType": "EXPENSE",
      "refId": "0192...",
      "isRead": false,
      "createdAt": "2026-11-01T03:00:00Z"
    }
  ],
  "nextCursor": "0192...",
  "hasNext": true
}
```

알림을 누르면 앱은 `refType` + `refId` 화면으로 이동한다 (`TRIP_DELETED`는 `refType`이 `null`).

| type | 보내는 때 | refType | 끌 수 있는 설정 |
|---|---|---|---|
| `SCHEDULE_CHANGED` | 일정 추가 · 수정 · 고정 해제 · 삭제 | `SCHEDULE` (삭제는 `TRIP`) | `notifySchedule` |
| `POLL_CREATED` | 투표 만들기 | `POLL` | `notifySchedule` |
| `POLL_CLOSED` | 투표 마감 (일정 반영) | `POLL` | `notifySchedule` |
| `TASK_ASSIGNED` | 함께 할 업무를 맡김 (담당자에게만) | `TASK` | `notifySchedule` |
| `EXPENSE_ADDED` | 지출 추가 | `EXPENSE` | `notifyExpense` |
| `SETTLEMENT_SHARED` | 정산 공유 | `SETTLEMENT_SHARE` | `notifySettlement` |
| `MEMBER_JOINED` | 초대 코드로 참여 | `TRIP` | 항상 |
| `TRIP_DELETED` | 여행 삭제 | `null` | 항상 |

- 변경한 본인에게는 보내지 않는다. 메시지는 255자에서 자른다
- 알림함에 저장하고, 트랜잭션이 커밋된 뒤 FCM 푸시를 따로 보낸다. 푸시의 `data`에 `tripId` · `type` · `refType` · `refId`가 들어 있어 앱이 같은 화면으로 이동한다. FCM 설정이 없는 서버는 알림함에만 쌓는다
- FCM이 무효라고 알린 토큰(`UNREGISTERED` · `INVALID_ARGUMENT` · `SENDER_ID_MISMATCH`)은 그때 지운다

### GET `/api/notifications/unread-count`

종 모양 배지용. `200 OK` — `{ "count": 3 }`

### PATCH `/api/notifications/{notificationId}/read`

`204 No Content`. 내 알림이 아니면 `404 NOTIFICATION_NOT_FOUND`

### PATCH `/api/notifications/read-all`

`204 No Content`

### PUT `/api/device-tokens` — FCM 토큰 등록·갱신

로그인·앱 실행 때 보낸다. 같은 토큰이 다른 계정에 있으면 지금 계정으로 옮긴다.

```json
{ "fcmToken": "fGx..." }
```

`204 No Content`

### DELETE `/api/device-tokens` — FCM 토큰 삭제

로그아웃 때 보낸다.

```json
{ "fcmToken": "fGx..." }
```

`204 No Content`
