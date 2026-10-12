# ERD

기준: [`V1__init.sql`](../../backend/src/main/resources/db/migration/V1__init.sql) (MySQL 8.4)

- 모든 PK/FK는 UUID v7을 `BINARY(16)`으로 저장한다 (값은 앱의 `BaseEntity`가 만든다)
- 시각은 `DATETIME(6)`에 UTC로 저장한다
- 리프레시 토큰은 Redis에 있으므로 테이블이 없다

## 전체 관계도

```mermaid
erDiagram
    users ||--o{ trip_members : "참여"
    users ||--o{ device_tokens : "회원 기기"
    users ||--o{ notifications : "회원 수신"

    trips ||--|{ trip_members : "멤버"
    trips ||--o{ tasks : ""
    trips ||--o{ schedules : ""
    trips ||--o{ polls : ""
    trips ||--o{ budget_items : ""
    trips ||--o{ expenses : ""
    trips ||--o{ settlement_shares : ""

    trip_members ||--o{ device_tokens : "게스트 기기"
    trip_members ||--o{ notifications : "게스트 수신"
    trip_members ||--o{ tasks : "작성"
    trip_members |o--o{ tasks : "담당"
    trip_members ||--o{ schedules : "작성"
    trip_members ||--o{ polls : "작성"
    trip_members ||--o{ poll_votes : "투표"
    trip_members ||--o{ expenses : "결제"
    trip_members ||--o{ expenses : "입력"
    trip_members ||--o{ expense_item_users : "분담"
    trip_members ||--o{ settlement_shares : "공유"
    trip_members ||--o{ settlement_transfers : "보냄"
    trip_members ||--o{ settlement_transfers : "받음"

    polls ||--|{ poll_options : "후보 1~6"
    polls |o--o| poll_options : "선택된 후보"
    polls }o--o| schedules : "반영된 일정"
    polls ||--o{ poll_votes : ""
    poll_options ||--o{ poll_votes : ""

    expenses ||--|{ expense_items : "항목"
    expense_items ||--|{ expense_item_users : "분담자"

    settlement_shares ||--|{ settlement_transfers : "송금 목록"

    users {
        BINARY16 id PK
        VARCHAR255 email UK "탈퇴 시 익명화"
        VARCHAR255 password_hash
        VARCHAR20 name
        VARCHAR10 role "USER | ADMIN"
        BOOLEAN notify_schedule
        BOOLEAN notify_expense
        BOOLEAN notify_settlement
        DATETIME created_at
        DATETIME updated_at
        DATETIME deleted_at "soft delete"
    }

    trips {
        BINARY16 id PK
        VARCHAR50 name
        VARCHAR100 destination
        DATE start_date
        DATE end_date "start_date 이상"
        CHAR3 currency_code "ISO 4217"
        CHAR8 invite_code UK
        DATETIME created_at
        DATETIME updated_at
    }

    trip_members {
        BINARY16 id PK
        BINARY16 trip_id FK
        BINARY16 user_id FK "게스트는 NULL"
        VARCHAR10 role "HOST | MEMBER | GUEST"
        VARCHAR20 display_name "게스트 이름 / 탈퇴 시 이름"
        CHAR64 guest_token_hash UK
        DECIMAL prepaid_rate "선불 환전 환율"
        DATETIME joined_at
        DATETIME left_at "나가기"
    }

    tasks {
        BINARY16 id PK
        BINARY16 trip_id FK
        BINARY16 creator_member_id FK
        BINARY16 assignee_member_id FK "NULL 허용"
        VARCHAR10 scope "PRIVATE | TEAM"
        VARCHAR100 title
        BOOLEAN is_done
        DATETIME created_at
        DATETIME updated_at
    }

    device_tokens {
        BINARY16 id PK
        BINARY16 user_id FK "회원"
        BINARY16 member_id FK "게스트"
        VARCHAR255 fcm_token UK
        DATETIME updated_at
    }

    notifications {
        BINARY16 id PK
        BINARY16 user_id FK "회원 수신자"
        BINARY16 member_id FK "게스트 수신자"
        BINARY16 trip_id "FK 없음"
        VARCHAR50 trip_name "스냅샷"
        VARCHAR30 type
        VARCHAR255 message
        VARCHAR30 ref_type
        BINARY16 ref_id
        BOOLEAN is_read
        DATETIME created_at
    }

    schedules {
        BINARY16 id PK
        BINARY16 trip_id FK
        DATE day
        TIME start_time
        TIME end_time "start_time 초과"
        VARCHAR100 title
        VARCHAR100 place_text
        BOOLEAN is_locked
        VARCHAR10 reservation_status "NONE | PENDING | CONFIRMED"
        VARCHAR500 memo
        BINARY16 created_by_member_id FK
        DATETIME created_at
        DATETIME updated_at
        INT version "낙관적 락"
    }

    polls {
        BINARY16 id PK
        BINARY16 trip_id FK
        BINARY16 creator_member_id FK
        VARCHAR100 title
        DATE slot_date
        TIME slot_start
        TIME slot_end
        DATETIME deadline_at
        VARCHAR10 status "OPEN | CLOSED"
        BINARY16 selected_option_id FK
        BINARY16 schedule_id FK
        DATETIME created_at
        DATETIME closed_at
    }

    poll_options {
        BINARY16 id PK
        BINARY16 poll_id FK
        VARCHAR100 label
        VARCHAR255 memo
        TINYINT sort_order "1~6"
    }

    poll_votes {
        BINARY16 id PK
        BINARY16 poll_id FK "UK(poll_id, member_id)"
        BINARY16 option_id FK
        BINARY16 member_id FK
        DATETIME updated_at
    }

    exchange_rates {
        BINARY16 id PK
        CHAR3 currency_code "UK(code, date)"
        DATE rate_date
        DECIMAL rate_to_krw "1단위 기준"
        DATETIME fetched_at
    }

    budget_items {
        BINARY16 id PK
        BINARY16 trip_id FK
        VARCHAR20 category
        VARCHAR100 name
        DECIMAL amount "0 이상"
        CHAR3 currency_code "KRW 또는 여행 통화"
        DATETIME created_at
    }

    expenses {
        BINARY16 id PK
        BINARY16 trip_id FK
        BINARY16 payer_member_id FK
        BINARY16 creator_member_id FK
        VARCHAR100 title
        VARCHAR20 category
        DATE paid_date
        DECIMAL amount_local "KRW 모드면 NULL"
        VARCHAR10 rate_mode "API | PREPAID | MANUAL | KRW"
        DECIMAL applied_rate "KRW 모드면 NULL"
        DATE rate_date
        DECIMAL amount_krw
        VARCHAR10 split_method "EQUAL | ITEM | CUSTOM"
        DATETIME created_at
        DATETIME updated_at
        INT version "낙관적 락"
    }

    expense_items {
        BINARY16 id PK
        BINARY16 expense_id FK
        VARCHAR100 name
        DECIMAL amount_local
        DECIMAL amount_krw
        SMALLINT sort_order
    }

    expense_item_users {
        BINARY16 item_id PK,FK
        BINARY16 member_id PK,FK
        DECIMAL share_krw
    }

    settlement_shares {
        BINARY16 id PK
        BINARY16 trip_id FK
        BINARY16 shared_by_member_id FK
        DATETIME created_at
    }

    settlement_transfers {
        BINARY16 id PK
        BINARY16 share_id FK
        BINARY16 from_member_id FK
        BINARY16 to_member_id FK
        DECIMAL amount_krw "0 초과"
    }
```

`exchange_rates`는 다른 테이블과 FK 없이 `currency_code` + 날짜로만 조회한다.

## 테이블 요약

| 영역 | 테이블 | 설명 |
|---|---|---|
| 회원 | `users` | 회원. 탈퇴는 `deleted_at` (soft delete) |
| 여행 | `trips` | 여행. 통화 1개, 초대 코드 8자리 |
| | `trip_members` | 여행 참여자. 회원(`user_id`) 또는 게스트(`guest_token_hash`) |
| 준비 | `tasks` | 준비 업무. `PRIVATE`(나만) / `TEAM`(공용) |
| 알림 | `device_tokens` | FCM 토큰. 회원/게스트 중 하나 |
| | `notifications` | 알림함. 여행이 삭제돼도 남는다 |
| 일정 | `schedules` | 하루 단위 시간표. 자정을 넘는 일정 불가 |
| 투표 | `polls` / `poll_options` / `poll_votes` | 일정 슬롯에 넣을 장소 투표. 후보 1~6개, 1인 1표 |
| 예산 | `exchange_rates` | 일자별 환율 캐시 (통화 1단위 → KRW) |
| | `budget_items` | 카테고리별 예산 |
| 지출 | `expenses` / `expense_items` / `expense_item_users` | 지출 → 항목 → 항목별 분담자·분담액 |
| 정산 | `settlement_shares` / `settlement_transfers` | 정산 결과를 공유한 시점의 송금 목록 스냅샷 |

## 코드값

| 컬럼 | 값 |
|---|---|
| `users.role` | `USER`, `ADMIN` |
| `trip_members.role` | `HOST`, `MEMBER`, `GUEST` |
| `tasks.scope` | `PRIVATE`, `TEAM` |
| `schedules.reservation_status` | `NONE`, `PENDING`, `CONFIRMED` |
| `polls.status` | `OPEN`, `CLOSED` |
| `expenses.category`, `budget_items.category` | `FOOD`, `LODGING`, `TRANSPORT`, `ACTIVITY`, `SHOPPING`, `ETC` |
| `expenses.rate_mode` | `API`(환율 API), `PREPAID`(본인 선불 환율), `MANUAL`(직접 입력), `KRW`(원화 직접) |
| `expenses.split_method` | `EQUAL`(N분의 1), `ITEM`(항목별), `CUSTOM`(금액 직접) |
| `notifications.type` | `SCHEDULE_CHANGED`, `EXPENSE_ADDED`, `SETTLEMENT_SHARED`, `TRIP_DELETED` |
| `notifications.ref_type` | `SCHEDULE`, `EXPENSE`, `SETTLEMENT_SHARE` |

## 삭제 정책

- 여행을 지우면 하위 데이터(멤버·업무·일정·투표·예산·지출·정산)가 전부 CASCADE로 지워진다
- 멤버는 지우지 않는다. 나가기는 `left_at` 기록, 다시 들어오면 `NULL`로 되돌린다
- 회원 탈퇴는 `deleted_at` 기록 + 이메일 익명화(앱 처리)
- `notifications.trip_id`는 FK가 없어서 여행 삭제 알림이 남는다

## 앱에서 검증할 것 (DB 제약 없음)

- `device_tokens`, `notifications`: `user_id` / `member_id` 중 정확히 하나만 값이 있어야 한다
- `settlement_transfers`: `from_member_id <> to_member_id`
- `poll_votes.option_id`, `polls.selected_option_id`가 같은 투표의 후보인지
