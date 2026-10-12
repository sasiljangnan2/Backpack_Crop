# API 명세

기준: [ERD](../erd/README.md) · [`V1__init.sql`](../../backend/src/main/resources/db/migration/V1__init.sql)

> 아직 컨트롤러가 없어서 **테이블 구조에서 뽑은 초안**이다. 구현하면서 바뀌는 부분은 이 문서도 같이 고친다.
> ⚠️ 표시는 팀이 정해야 하는 부분이다.

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

도메인별 코드(`USER_NOT_FOUND` 등)는 구현하면서 `ErrorCode`에 추가하고 이 표에도 적는다.

### 낙관적 락

`schedules`, `expenses`는 `version`을 가진다. 수정 요청에 조회 때 받은 `version`을 함께 보내고, 그 사이 다른 사람이 고쳤으면 `409 CONFLICT`를 받는다. 앱은 다시 조회해서 보여 준다.

---

## 2. 엔드포인트 목록

| 영역 | 메서드 | URL | 설명 |
|---|---|---|---|
| 인증 | POST | `/api/auth/signup` | 회원가입 |
| | POST | `/api/auth/login` | 로그인 |
| | POST | `/api/auth/reissue` | 토큰 재발급 |
| | POST | `/api/auth/logout` | 로그아웃 |
| 회원 | GET | `/api/users/me` | 내 정보 |
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
| | POST | `/api/trips/{tripId}/schedules` | 추가 |
| | PATCH | `/api/trips/{tripId}/schedules/{scheduleId}` | 수정 |
| | DELETE | `/api/trips/{tripId}/schedules/{scheduleId}` | 삭제 |
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
| | GET | `/api/trips/{tripId}/expenses/{expenseId}` | 상세 |
| | PUT | `/api/trips/{tripId}/expenses/{expenseId}` | 수정 (전체 교체) |
| | DELETE | `/api/trips/{tripId}/expenses/{expenseId}` | 삭제 |
| 정산 | GET | `/api/trips/{tripId}/settlement` | 현재 정산 계산 결과 |
| | POST | `/api/trips/{tripId}/settlement-shares` | 정산 결과 공유 (스냅샷 저장) |
| | GET | `/api/trips/{tripId}/settlement-shares` | 공유 이력 |
| | GET | `/api/trips/{tripId}/settlement-shares/{shareId}` | 공유 상세 |
| 알림 | GET | `/api/notifications` | 알림함 (커서) |
| | PATCH | `/api/notifications/{notificationId}/read` | 읽음 처리 |
| | PATCH | `/api/notifications/read-all` | 모두 읽음 |
| | PUT | `/api/device-tokens` | FCM 토큰 등록·갱신 |
| | DELETE | `/api/device-tokens` | FCM 토큰 삭제 |

---

## 3. 인증 · 회원

### POST `/api/auth/signup` — 회원가입

인증 불필요.

```json
{ "email": "user@example.com", "password": "password123!", "name": "홍길동" }
```

| 필드 | 규칙 |
|---|---|
| email | 필수, 이메일 형식, 최대 255자 |
| password | 필수 ⚠️ 규칙 미정 (예: 8~64자) |
| name | 필수, 1~20자 |

`201 Created`

```json
{ "id": "0192...", "email": "user@example.com", "name": "홍길동" }
```

에러: `409 CONFLICT` 이메일 중복

### POST `/api/auth/login` — 로그인

인증 불필요.

```json
{ "email": "user@example.com", "password": "password123!" }
```

`200 OK`

```json
{ "accessToken": "eyJ...", "refreshToken": "q8Zx..." }
```

에러: `401 UNAUTHORIZED` 이메일·비밀번호 불일치 또는 탈퇴 회원

### POST `/api/auth/reissue` — 토큰 재발급

인증 불필요. 리프레시 토큰은 한 번 쓰면 30초 뒤 무효가 되므로 **응답의 새 리프레시 토큰으로 꼭 바꿔 저장**한다.

```json
{ "refreshToken": "q8Zx..." }
```

`200 OK` — 로그인과 같은 형식. 에러: `401 UNAUTHORIZED` (다시 로그인)

### POST `/api/auth/logout` — 로그아웃

```json
{ "refreshToken": "q8Zx..." }
```

`204 No Content`

### GET `/api/users/me` — 내 정보

`200 OK`

```json
{
  "id": "0192...",
  "email": "user@example.com",
  "name": "홍길동",
  "notifySchedule": true,
  "notifyExpense": true,
  "notifySettlement": true
}
```

### PATCH `/api/users/me` — 이름 변경

```json
{ "name": "김철수" }
```

`200 OK` — 내 정보와 같은 형식

### PATCH `/api/users/me/password` — 비밀번호 변경

모든 기기의 리프레시 토큰이 무효가 된다.

```json
{ "currentPassword": "old", "newPassword": "new" }
```

`204 No Content`. 에러: `400 BAD_REQUEST` 현재 비밀번호 불일치

### PATCH `/api/users/me/notification-settings` — 알림 설정

보낸 필드만 바뀐다.

```json
{ "notifySchedule": false, "notifyExpense": true, "notifySettlement": true }
```

`200 OK` — 내 정보와 같은 형식

### DELETE `/api/users/me` — 탈퇴

`deleted_at` 기록, 이메일 익명화, 모든 리프레시 토큰 폐기. 참여 중인 여행의 멤버 행은 남기고 `display_name`에 탈퇴 시점 이름을 저장한다.

```json
{ "password": "password123!" }
```

`204 No Content`

⚠️ 방장인 여행이 있으면 어떻게 할지(위임/삭제/탈퇴 불가) 미정.

---

## 4. 여행 · 멤버

### POST `/api/trips` — 여행 만들기

만든 사람이 `HOST` 멤버가 되고, 초대 코드 8자리가 자동 발급된다.

```json
{
  "name": "오사카 먹방",
  "destination": "일본 오사카",
  "startDate": "2026-11-01",
  "endDate": "2026-11-04",
  "currencyCode": "JPY"
}
```

| 필드 | 규칙 |
|---|---|
| name | 필수, 최대 50자 |
| destination | 필수, 최대 100자 |
| startDate / endDate | 필수, `endDate >= startDate` |
| currencyCode | 필수, ISO 4217 3자리 |

`201 Created` — 여행 상세와 같은 형식

### GET `/api/trips` — 내 여행 목록

내가 현재 멤버인 여행. 시작일 내림차순.

`200 OK`

```json
[
  {
    "id": "0192...",
    "name": "오사카 먹방",
    "destination": "일본 오사카",
    "startDate": "2026-11-01",
    "endDate": "2026-11-04",
    "currencyCode": "JPY",
    "memberCount": 4,
    "myRole": "HOST"
  }
]
```

### GET `/api/trips/{tripId}` — 여행 상세

`200 OK`

```json
{
  "id": "0192...",
  "name": "오사카 먹방",
  "destination": "일본 오사카",
  "startDate": "2026-11-01",
  "endDate": "2026-11-04",
  "currencyCode": "JPY",
  "inviteCode": "A7K2M9QX",
  "myMemberId": "0192...",
  "myRole": "HOST",
  "createdAt": "2026-10-12T03:00:00Z"
}
```

### PATCH `/api/trips/{tripId}` 🔑 — 여행 수정

`name`, `destination`, `startDate`, `endDate` 중 보낸 필드만 바뀐다. ⚠️ 통화 변경은 기존 지출 환율과 어긋나므로 막는 것을 권장.

`200 OK` — 여행 상세와 같은 형식

### DELETE `/api/trips/{tripId}` 🔑 — 여행 삭제

하위 데이터가 모두 삭제되고, 멤버 전원에게 `TRIP_DELETED` 알림이 간다.

`204 No Content`

### POST `/api/trips/join` — 참여 (회원)

나갔던 여행이면 `left_at`을 지우고 다시 참여한다.

```json
{ "inviteCode": "A7K2M9QX" }
```

`200 OK` — 여행 상세와 같은 형식. 에러: `404 NOT_FOUND` 코드 없음

### POST `/api/trips/join/guest` — 참여 (게스트) ⚠️

인증 불필요. 응답의 `guestToken`은 이때 한 번만 내려가며 서버에는 해시만 남는다.

```json
{ "inviteCode": "A7K2M9QX", "displayName": "민지" }
```

`201 Created`

```json
{ "tripId": "0192...", "memberId": "0192...", "guestToken": "gT9..." }
```

### GET `/api/trips/{tripId}/members` — 멤버 목록

현재 멤버만. 탈퇴 회원은 `display_name`으로 표시.

`200 OK`

```json
[
  { "memberId": "0192...", "name": "홍길동", "role": "HOST", "isMe": true, "prepaidRate": 9.12, "joinedAt": "2026-10-12T03:00:00Z" }
]
```

### DELETE `/api/trips/{tripId}/members/me` — 나가기

`left_at`만 기록한다(지출·정산 기록 유지). ⚠️ 방장이 나갈 때 위임 규칙 미정.

`204 No Content`

### PATCH `/api/trips/{tripId}/members/me/prepaid-rate` — 내 선불 환율

환전해 간 환율. 지출의 `rateMode = PREPAID`에서 쓴다. `null`이면 해제.

```json
{ "prepaidRate": 9.120000 }
```

`200 OK` — 멤버 한 명 형식

---

## 5. 준비 업무

### GET `/api/trips/{tripId}/tasks?scope=TEAM`

| 쿼리 | 설명 |
|---|---|
| scope | `PRIVATE`(내가 만든 개인 업무) / `TEAM`. 생략하면 둘 다 |

`PRIVATE` 업무는 만든 사람만 볼 수 있다.

`200 OK`

```json
[
  {
    "id": "0192...",
    "scope": "TEAM",
    "title": "숙소 예약",
    "isDone": false,
    "creator": { "memberId": "0192...", "name": "홍길동" },
    "assignee": { "memberId": "0192...", "name": "김철수" },
    "createdAt": "2026-10-12T03:00:00Z"
  }
]
```

### POST `/api/trips/{tripId}/tasks`

```json
{ "scope": "TEAM", "title": "숙소 예약", "assigneeMemberId": "0192..." }
```

| 필드 | 규칙 |
|---|---|
| scope | 필수 |
| title | 필수, 최대 100자 |
| assigneeMemberId | 선택. 같은 여행의 멤버. `PRIVATE`이면 무시 |

`201 Created` — 목록 항목 형식

### PATCH `/api/trips/{tripId}/tasks/{taskId}`

`title`, `assigneeMemberId`, `isDone` 중 보낸 필드만 바뀐다. `PRIVATE`은 만든 사람만 수정 가능.

`200 OK` — 목록 항목 형식

### DELETE `/api/trips/{tripId}/tasks/{taskId}`

`204 No Content`

---

## 6. 일정

### GET `/api/trips/{tripId}/schedules?day=2026-11-01`

`day` 생략 시 전체. `day`, `startTime` 오름차순.

`200 OK`

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
    "createdBy": { "memberId": "0192...", "name": "홍길동" },
    "version": 3,
    "updatedAt": "2026-10-12T03:00:00Z"
  }
]
```

### POST `/api/trips/{tripId}/schedules`

멤버들에게 `SCHEDULE_CHANGED` 알림.

```json
{
  "day": "2026-11-01",
  "startTime": "12:00",
  "endTime": "13:30",
  "title": "점심",
  "placeText": "이치란 도톤보리점",
  "reservationStatus": "NONE",
  "memo": null
}
```

| 필드 | 규칙 |
|---|---|
| day | 필수, 여행 기간 안 |
| startTime / endTime | 필수, `endTime > startTime` (자정 넘김 불가) |
| title | 필수, 최대 100자 |
| placeText | 선택, 최대 100자 |
| reservationStatus | 선택, 기본 `NONE` |
| memo | 선택, 최대 500자 |

`201 Created` — 목록 항목 형식

### PATCH `/api/trips/{tripId}/schedules/{scheduleId}`

`version` 필수, 나머지는 보낸 필드만 바뀐다. `isLocked`도 여기서 바꾼다. 잠긴 일정은 `isLocked: false` 외의 수정이 `409 CONFLICT`.

```json
{ "version": 3, "startTime": "12:30", "isLocked": true }
```

`200 OK` — 목록 항목 형식. 에러: `409 CONFLICT` 버전 불일치 / 잠금

### DELETE `/api/trips/{tripId}/schedules/{scheduleId}`

잠긴 일정은 `409 CONFLICT`. `204 No Content`

---

## 7. 장소 투표

### GET `/api/trips/{tripId}/polls?status=OPEN`

`status` 생략 시 전체. 최신순.

`200 OK`

```json
[
  {
    "id": "0192...",
    "title": "둘째 날 저녁",
    "slotDate": "2026-11-02",
    "slotStart": "18:00",
    "slotEnd": "20:00",
    "deadlineAt": "2026-10-30T12:00:00Z",
    "status": "OPEN",
    "voteCount": 3,
    "voted": true
  }
]
```

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
| slotDate / slotStart / slotEnd | 필수, `slotEnd > slotStart` |
| deadlineAt | 선택. 지나면 투표 불가 ⚠️ 자동 마감 여부 미정 |
| options | 필수, 1~6개 ⚠️ 최소 2개 권장. 순서대로 `sortOrder` 1~6 |
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
  "creator": { "memberId": "0192...", "name": "홍길동" },
  "options": [
    { "id": "0192...", "label": "야키니쿠 A", "memo": "도보 5분", "sortOrder": 1, "voteCount": 2 },
    { "id": "0192...", "label": "오코노미야키 B", "memo": null, "sortOrder": 2, "voteCount": 1 }
  ],
  "myOptionId": "0192...",
  "selectedOptionId": null,
  "scheduleId": null,
  "createdAt": "2026-10-12T03:00:00Z",
  "closedAt": null
}
```

### PUT `/api/trips/{tripId}/polls/{pollId}/votes/me` — 투표·변경

1인 1표. 이미 투표했으면 후보만 바꾼다.

```json
{ "optionId": "0192..." }
```

`200 OK` — 상세 형식. 에러: `400 BAD_REQUEST` 다른 투표의 후보 / `409 CONFLICT` 마감됨

### DELETE `/api/trips/{tripId}/polls/{pollId}/votes/me` — 투표 취소

`204 No Content`. 에러: `409 CONFLICT` 마감됨

### POST `/api/trips/{tripId}/polls/{pollId}/close` — 마감

만든 사람만 ⚠️ (방장 포함 여부 미정). 선택한 후보로 슬롯에 일정을 만들고 `scheduleId`에 연결한다. `selectedOptionId`를 생략하면 일정 없이 마감만 한다.

```json
{ "selectedOptionId": "0192..." }
```

`200 OK` — 상세 형식 (`status: CLOSED`, `scheduleId` 채워짐). 에러: `409 CONFLICT` 이미 마감

### DELETE `/api/trips/{tripId}/polls/{pollId}`

만든 사람만. 반영된 일정은 남는다. `204 No Content`

---

## 8. 환율 · 예산

### GET `/api/exchange-rates?currencyCode=JPY&date=2026-11-01`

통화 1단위 → KRW. DB에 없으면 외부 API에서 가져와 저장한다. 주말·장애로 그 날짜 값이 없으면 가장 가까운 이전 날짜 값을 주고 `rateDate`에 실제 날짜를 담는다.

| 쿼리 | 설명 |
|---|---|
| currencyCode | 필수 |
| date | 선택, 기본 오늘 |

`200 OK`

```json
{ "currencyCode": "JPY", "rateDate": "2026-10-30", "rateToKrw": 9.124500 }
```

### GET `/api/trips/{tripId}/budget-items`

예산 항목과 카테고리별 합계(예산 vs 실제 지출, 원화 환산).

`200 OK`

```json
{
  "items": [
    { "id": "0192...", "category": "LODGING", "name": "호텔 3박", "amount": 450000, "currencyCode": "KRW", "createdAt": "2026-10-12T03:00:00Z" }
  ],
  "summary": [
    { "category": "LODGING", "budgetKrw": 450000, "spentKrw": 430000 }
  ],
  "totalBudgetKrw": 1200000,
  "totalSpentKrw": 860000
}
```

⚠️ 여행 통화 예산의 원화 환산 기준(오늘 환율 등) 미정.

### POST `/api/trips/{tripId}/budget-items`

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

### PATCH `/api/trips/{tripId}/budget-items/{budgetItemId}`

보낸 필드만 바뀐다. `200 OK`

### DELETE `/api/trips/{tripId}/budget-items/{budgetItemId}`

`204 No Content`

---

## 9. 지출

### GET `/api/trips/{tripId}/expenses`

| 쿼리 | 설명 |
|---|---|
| date | 선택, `paidDate` 필터 |
| category | 선택 |
| cursor / size | 커서 페이지 (최신순) |

`200 OK`

```json
{
  "content": [
    {
      "id": "0192...",
      "title": "이치란",
      "category": "FOOD",
      "paidDate": "2026-11-01",
      "amountLocal": 4800.00,
      "amountKrw": 43798,
      "payer": { "memberId": "0192...", "name": "홍길동" },
      "myShareKrw": 10949
    }
  ],
  "nextCursor": "0192...",
  "hasNext": true
}
```

### POST `/api/trips/{tripId}/expenses`

멤버들에게 `EXPENSE_ADDED` 알림. 서버가 `appliedRate`, `amountKrw`, 항목별 `amountKrw`, 분담액 `shareKrw`를 계산해 저장한다. 원 단위 나머지는 결제자가 부담한다.

```json
{
  "payerMemberId": "0192...",
  "title": "이치란",
  "category": "FOOD",
  "paidDate": "2026-11-01",
  "rateMode": "API",
  "amountLocal": 4800.00,
  "manualRate": null,
  "amountKrw": null,
  "splitMethod": "ITEM",
  "items": [
    { "name": "라멘 A", "amountLocal": 1200.00, "amountKrw": null, "members": [ { "memberId": "0192..." } ] },
    { "name": "라멘 B + 맥주", "amountLocal": 3600.00, "amountKrw": null, "members": [ { "memberId": "0192..." }, { "memberId": "0192..." } ] }
  ]
}
```

**환율 모드(`rateMode`)**

| 값 | 필요한 값 | 적용 환율 |
|---|---|---|
| `API` | `amountLocal` | `paidDate`의 환율 (`exchange_rates`) |
| `PREPAID` | `amountLocal` | 결제자의 `prepaidRate` (없으면 `400`) |
| `MANUAL` | `amountLocal`, `manualRate` | 입력한 환율 |
| `KRW` | `amountKrw` | 없음. `amountLocal`·`appliedRate`는 `null` |

**분담 방식(`splitMethod`)**

| 값 | `items` |
|---|---|
| `EQUAL` | 항목 1개(총액). `members`에 분담자, 금액은 N분의 1 |
| `ITEM` | 항목 여러 개. 항목마다 금액과 분담자, 항목 안에서 N분의 1 |
| `CUSTOM` | 항목 1개. `members[].shareKrw`로 사람별 금액 직접 입력, 합계 = 총액 |

공통 규칙

- `payerMemberId`, `members[].memberId`는 같은 여행의 멤버
- 항목 금액 합계 = 지출 총액, 항목마다 분담자 1명 이상
- 대리 입력: 요청한 사람이 `creator`, `payerMemberId`가 결제자

`201 Created` — 상세 형식

### GET `/api/trips/{tripId}/expenses/{expenseId}`

`200 OK`

```json
{
  "id": "0192...",
  "title": "이치란",
  "category": "FOOD",
  "paidDate": "2026-11-01",
  "rateMode": "API",
  "amountLocal": 4800.00,
  "appliedRate": 9.124500,
  "rateDate": "2026-10-30",
  "amountKrw": 43798,
  "splitMethod": "ITEM",
  "payer": { "memberId": "0192...", "name": "홍길동" },
  "creator": { "memberId": "0192...", "name": "홍길동" },
  "items": [
    {
      "id": "0192...",
      "name": "라멘 A",
      "amountLocal": 1200.00,
      "amountKrw": 10949,
      "sortOrder": 1,
      "members": [ { "memberId": "0192...", "name": "김철수", "shareKrw": 10949 } ]
    }
  ],
  "version": 0,
  "createdAt": "2026-10-12T03:00:00Z",
  "updatedAt": "2026-10-12T03:00:00Z"
}
```

### PUT `/api/trips/{tripId}/expenses/{expenseId}`

추가와 같은 바디 + `version`. 항목·분담자를 통째로 교체한다. ⚠️ 수정 권한(결제자·작성자만?) 미정.

`200 OK` — 상세 형식. 에러: `409 CONFLICT` 버전 불일치

### DELETE `/api/trips/{tripId}/expenses/{expenseId}`

`204 No Content`

---

## 10. 정산

정산은 저장하지 않고 요청 때마다 지출에서 계산한다. "공유"할 때만 그 시점의 송금 목록을 저장한다.

### GET `/api/trips/{tripId}/settlement` — 현재 정산

`200 OK`

```json
{
  "totalKrw": 860000,
  "members": [
    { "memberId": "0192...", "name": "홍길동", "paidKrw": 500000, "shareKrw": 215000, "balanceKrw": 285000 }
  ],
  "transfers": [
    { "from": { "memberId": "0192...", "name": "김철수" }, "to": { "memberId": "0192...", "name": "홍길동" }, "amountKrw": 95000 }
  ]
}
```

- `balanceKrw = paidKrw - shareKrw` (양수면 받을 돈)
- `transfers`는 송금 횟수를 최소로 줄인 목록

### POST `/api/trips/{tripId}/settlement-shares` — 공유

현재 `transfers`를 저장하고 멤버들에게 `SETTLEMENT_SHARED` 알림. 바디 없음.

`201 Created` — 공유 상세 형식. 에러: `409 CONFLICT` 송금할 내역 없음

### GET `/api/trips/{tripId}/settlement-shares` — 공유 이력

최신순.

```json
[ { "id": "0192...", "sharedBy": { "memberId": "0192...", "name": "홍길동" }, "transferCount": 3, "createdAt": "2026-11-05T03:00:00Z" } ]
```

### GET `/api/trips/{tripId}/settlement-shares/{shareId}` — 공유 상세

```json
{
  "id": "0192...",
  "sharedBy": { "memberId": "0192...", "name": "홍길동" },
  "createdAt": "2026-11-05T03:00:00Z",
  "transfers": [
    { "id": "0192...", "from": { "memberId": "0192...", "name": "김철수" }, "to": { "memberId": "0192...", "name": "홍길동" }, "amountKrw": 95000 }
  ]
}
```

---

## 11. 알림

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

| type | 보내는 때 | 끌 수 있는 설정 |
|---|---|---|
| `SCHEDULE_CHANGED` | 일정 추가·수정·삭제, 투표 반영 | `notifySchedule` |
| `EXPENSE_ADDED` | 지출 추가 | `notifyExpense` |
| `SETTLEMENT_SHARED` | 정산 공유 | `notifySettlement` |
| `TRIP_DELETED` | 여행 삭제 | 항상 |

변경한 본인에게는 보내지 않는다.

### PATCH `/api/notifications/{notificationId}/read`

`204 No Content`

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
