-- =====================================================================
-- Backpack DB Schema (MySQL 8.4+)
-- 기준: backpack_erd_v2 + 리뷰 반영 (2차 개발 컬럼 제외)
-- 문자셋: utf8mb4 / 엔진: InnoDB
-- ID: 모든 PK/FK는 UUID v7을 BINARY(16)으로 저장. 값은 애플리케이션(BaseEntity)이 생성
--     조회 시 BIN_TO_UUID(id), 조건 시 UUID_TO_BIN('...') 사용
-- 시각: DATETIME(6)에 UTC로 저장 (앱이 Instant를 UTC로 기록). DB 시간대도 UTC여야
--     DEFAULT/ON UPDATE CURRENT_TIMESTAMP 값이 앱이 쓴 값과 어긋나지 않는다
--
-- 삭제 정책
--   * 여행 삭제(TRIPS DELETE) 시 여행 하위 데이터는 모두 CASCADE로 함께 삭제
--   * 멤버는 물리 삭제하지 않음(나가기 = left_at 기록). 멤버 FK의 CASCADE는
--     여행 삭제 때만 동작함
--   * 회원은 soft delete(deleted_at). 탈퇴 시 email 익명화는 애플리케이션에서 처리
--   * NOTIFICATIONS.trip_id 는 FK 없음 → 여행 삭제 알림이 남음
--
-- 애플리케이션에서 검증할 것 (DB 제약으로 걸 수 없음)
--   * DEVICE_TOKENS, NOTIFICATIONS: user_id / member_id 중 정확히 하나만 값
--   * SETTLEMENT_TRANSFERS: from_member_id <> to_member_id
--   * POLL_VOTES.option_id, POLLS.selected_option_id 가 같은 투표의 후보인지
--   (MySQL은 CASCADE/SET NULL 동작이 걸린 컬럼에 CHECK 제약을 허용하지 않음)
-- =====================================================================

-- DB 생성은 Flyway 밖에서 한다 (로컬: docker-compose의 MYSQL_DATABASE).
-- 테이블은 DB 기본 문자셋을 따르므로 DB는 utf8mb4 / utf8mb4_0900_ai_ci 로 만들 것 (MySQL 8.4 기본값)

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- A. 회원 · 인증
-- ---------------------------------------------------------------------
CREATE TABLE users (
    id                 BINARY(16)   NOT NULL,
    email              VARCHAR(255) NOT NULL COMMENT '탈퇴 시 익명화',
    password_hash      VARCHAR(255) NOT NULL,
    name               VARCHAR(20)  NOT NULL COMMENT '1~20자',
    role               VARCHAR(10)  NOT NULL DEFAULT 'USER' COMMENT 'USER | ADMIN',
    notify_schedule    BOOLEAN      NOT NULL DEFAULT TRUE,
    notify_expense     BOOLEAN      NOT NULL DEFAULT TRUE,
    notify_settlement  BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at         DATETIME(6)  NULL COMMENT 'soft delete',
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_email (email),
    CONSTRAINT ck_users_role CHECK (role IN ('USER', 'ADMIN'))
) ENGINE=InnoDB;

-- 리프레시 토큰은 Redis에 저장한다 (테이블 없음)

-- ---------------------------------------------------------------------
-- A. 여행 · 멤버
-- ---------------------------------------------------------------------
CREATE TABLE trips (
    id             BINARY(16)   NOT NULL,
    name           VARCHAR(50)  NOT NULL,
    destination    VARCHAR(100) NOT NULL,
    start_date     DATE         NOT NULL,
    end_date       DATE         NOT NULL,
    currency_code  CHAR(3)      NOT NULL COMMENT '여행지 통화 1개 (ISO 4217)',
    invite_code    CHAR(8)      NOT NULL,
    created_at     DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at     DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_trips_invite_code (invite_code),
    CONSTRAINT ck_trips_period CHECK (end_date >= start_date)
) ENGINE=InnoDB;

CREATE TABLE trip_members (
    id                BINARY(16)    NOT NULL,
    trip_id           BINARY(16)    NOT NULL,
    user_id           BINARY(16)    NULL COMMENT '게스트는 NULL',
    role              VARCHAR(10)   NOT NULL COMMENT 'HOST | MEMBER | GUEST',
    display_name      VARCHAR(20)   NULL COMMENT '게스트 이름 / 탈퇴 시점 이름 보존',
    guest_token_hash  CHAR(64)      NULL COMMENT '게스트만',
    prepaid_rate      DECIMAL(15,6) NULL COMMENT '본인 선불 환전 환율 (여행 통화 1단위 → KRW)',
    joined_at         DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    left_at           DATETIME(6)   NULL COMMENT '나가기. 재참여 시 NULL로 복구',
    PRIMARY KEY (id),
    UNIQUE KEY uk_trip_members_trip_user (trip_id, user_id),
    UNIQUE KEY uk_trip_members_guest_token (guest_token_hash),
    KEY idx_trip_members_user (user_id),
    CONSTRAINT fk_trip_members_trip FOREIGN KEY (trip_id)
        REFERENCES trips (id) ON DELETE CASCADE,
    CONSTRAINT fk_trip_members_user FOREIGN KEY (user_id)
        REFERENCES users (id),
    CONSTRAINT ck_trip_members_role CHECK (role IN ('HOST', 'MEMBER', 'GUEST'))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- A. 준비 업무
-- ---------------------------------------------------------------------
CREATE TABLE tasks (
    id                  BINARY(16)   NOT NULL,
    trip_id             BINARY(16)   NOT NULL,
    creator_member_id   BINARY(16)   NOT NULL,
    assignee_member_id  BINARY(16)   NULL COMMENT '미지정 허용',
    scope               VARCHAR(10)  NOT NULL COMMENT 'PRIVATE | TEAM',
    title               VARCHAR(100) NOT NULL,
    is_done             BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at          DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at          DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_tasks_trip_scope (trip_id, scope),
    KEY idx_tasks_creator (creator_member_id),
    KEY idx_tasks_assignee (assignee_member_id),
    CONSTRAINT fk_tasks_trip FOREIGN KEY (trip_id)
        REFERENCES trips (id) ON DELETE CASCADE,
    CONSTRAINT fk_tasks_creator FOREIGN KEY (creator_member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE,
    CONSTRAINT fk_tasks_assignee FOREIGN KEY (assignee_member_id)
        REFERENCES trip_members (id) ON DELETE SET NULL,
    CONSTRAINT ck_tasks_scope CHECK (scope IN ('PRIVATE', 'TEAM'))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- B. 알림
-- ---------------------------------------------------------------------
CREATE TABLE device_tokens (
    id          BINARY(16)   NOT NULL,
    user_id     BINARY(16)   NULL COMMENT '회원',
    member_id   BINARY(16)   NULL COMMENT '게스트',
    fcm_token   VARCHAR(255) NOT NULL,
    updated_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_device_tokens_fcm (fcm_token),
    KEY idx_device_tokens_user (user_id),
    KEY idx_device_tokens_member (member_id),
    CONSTRAINT fk_device_tokens_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_device_tokens_member FOREIGN KEY (member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE notifications (
    id          BINARY(16)   NOT NULL,
    user_id     BINARY(16)   NULL COMMENT '회원 수신자',
    member_id   BINARY(16)   NULL COMMENT '게스트 수신자',
    trip_id     BINARY(16)   NOT NULL COMMENT 'FK 없음: 여행 삭제 후에도 보존',
    trip_name   VARCHAR(50)  NOT NULL COMMENT '스냅샷',
    type        VARCHAR(30)  NOT NULL COMMENT '예: SCHEDULE_CHANGED, EXPENSE_ADDED, SETTLEMENT_SHARED, TRIP_DELETED',
    message     VARCHAR(255) NOT NULL,
    ref_type    VARCHAR(30)  NULL COMMENT '눌렀을 때 이동 대상',
    ref_id      BINARY(16)   NULL,
    is_read     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_notifications_user (user_id, is_read, created_at),
    KEY idx_notifications_member (member_id, is_read, created_at),
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_notifications_member FOREIGN KEY (member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- C. 일정
-- ---------------------------------------------------------------------
CREATE TABLE schedules (
    id                    BINARY(16)   NOT NULL,
    trip_id               BINARY(16)   NOT NULL,
    day                   DATE         NOT NULL,
    start_time            TIME         NOT NULL,
    end_time              TIME         NOT NULL,
    title                 VARCHAR(100) NOT NULL,
    place_text            VARCHAR(100) NULL,
    is_locked             BOOLEAN      NOT NULL DEFAULT FALSE,
    reservation_status    VARCHAR(10)  NOT NULL DEFAULT 'NONE' COMMENT 'NONE | PENDING | CONFIRMED',
    memo                  VARCHAR(500) NULL,
    created_by_member_id  BINARY(16)   NOT NULL,
    created_at            DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at            DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    version               INT          NOT NULL DEFAULT 0 COMMENT '낙관적 락',
    PRIMARY KEY (id),
    KEY idx_schedules_trip_day (trip_id, day, start_time),
    KEY idx_schedules_creator (created_by_member_id),
    CONSTRAINT fk_schedules_trip FOREIGN KEY (trip_id)
        REFERENCES trips (id) ON DELETE CASCADE,
    CONSTRAINT fk_schedules_creator FOREIGN KEY (created_by_member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE,
    CONSTRAINT ck_schedules_time CHECK (end_time > start_time),  -- 자정 넘는 일정 불가
    CONSTRAINT ck_schedules_reservation CHECK (reservation_status IN ('NONE', 'PENDING', 'CONFIRMED'))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- C. 장소 투표
-- ---------------------------------------------------------------------
CREATE TABLE polls (
    id                  BINARY(16)   NOT NULL,
    trip_id             BINARY(16)   NOT NULL,
    creator_member_id   BINARY(16)   NOT NULL,
    title               VARCHAR(100) NOT NULL,
    slot_date           DATE         NOT NULL COMMENT '반영할 일정 슬롯',
    slot_start          TIME         NOT NULL,
    slot_end            TIME         NOT NULL,
    deadline_at         DATETIME(6)  NULL COMMENT '마감 시간',
    status              VARCHAR(10)  NOT NULL DEFAULT 'OPEN' COMMENT 'OPEN | CLOSED',
    selected_option_id  BINARY(16)   NULL COMMENT 'FK는 poll_options 생성 후 추가',
    schedule_id         BINARY(16)   NULL COMMENT '반영된 일정',
    created_at          DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    closed_at           DATETIME(6)  NULL,
    PRIMARY KEY (id),
    KEY idx_polls_trip_status (trip_id, status),
    KEY idx_polls_creator (creator_member_id),
    KEY idx_polls_schedule (schedule_id),
    CONSTRAINT fk_polls_trip FOREIGN KEY (trip_id)
        REFERENCES trips (id) ON DELETE CASCADE,
    CONSTRAINT fk_polls_creator FOREIGN KEY (creator_member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE,
    CONSTRAINT fk_polls_schedule FOREIGN KEY (schedule_id)
        REFERENCES schedules (id) ON DELETE SET NULL,
    CONSTRAINT ck_polls_slot CHECK (slot_end > slot_start),
    CONSTRAINT ck_polls_status CHECK (status IN ('OPEN', 'CLOSED'))
) ENGINE=InnoDB;

CREATE TABLE poll_options (
    id          BINARY(16)   NOT NULL,
    poll_id     BINARY(16)   NOT NULL,
    label       VARCHAR(100) NOT NULL,
    memo        VARCHAR(255) NULL COMMENT '도보·대기·비용 등 (선택)',
    sort_order  TINYINT      NOT NULL COMMENT '1~6',
    PRIMARY KEY (id),
    UNIQUE KEY uk_poll_options_order (poll_id, sort_order),
    CONSTRAINT fk_poll_options_poll FOREIGN KEY (poll_id)
        REFERENCES polls (id) ON DELETE CASCADE,
    CONSTRAINT ck_poll_options_order CHECK (sort_order BETWEEN 1 AND 6)
) ENGINE=InnoDB;

-- 순환 참조(polls ↔ poll_options)라 테이블 생성 후 추가
ALTER TABLE polls
    ADD CONSTRAINT fk_polls_selected_option FOREIGN KEY (selected_option_id)
        REFERENCES poll_options (id) ON DELETE SET NULL;

CREATE TABLE poll_votes (
    id          BINARY(16)  NOT NULL,
    poll_id     BINARY(16)  NOT NULL,
    option_id   BINARY(16)  NOT NULL,
    member_id   BINARY(16)  NOT NULL,
    updated_at  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_poll_votes_one_per_member (poll_id, member_id) COMMENT '1인 1표',
    KEY idx_poll_votes_option (option_id),
    KEY idx_poll_votes_member (member_id),
    CONSTRAINT fk_poll_votes_poll FOREIGN KEY (poll_id)
        REFERENCES polls (id) ON DELETE CASCADE,
    CONSTRAINT fk_poll_votes_option FOREIGN KEY (option_id)
        REFERENCES poll_options (id) ON DELETE CASCADE,
    CONSTRAINT fk_poll_votes_member FOREIGN KEY (member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- C. 환율 · 예산
-- ---------------------------------------------------------------------
CREATE TABLE exchange_rates (
    id             BINARY(16)    NOT NULL,
    currency_code  CHAR(3)       NOT NULL,
    rate_date      DATE          NOT NULL,
    rate_to_krw    DECIMAL(15,6) NOT NULL COMMENT '1단위 기준 (JPY·IDR 100단위 값은 /100 해서 저장)',
    fetched_at     DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_exchange_rates_code_date (currency_code, rate_date)
) ENGINE=InnoDB;

CREATE TABLE budget_items (
    id             BINARY(16)    NOT NULL,
    trip_id        BINARY(16)    NOT NULL,
    category       VARCHAR(20)   NOT NULL COMMENT 'expenses.category 와 같은 코드',
    name           VARCHAR(100)  NOT NULL,
    amount         DECIMAL(15,2) NOT NULL,
    currency_code  CHAR(3)       NOT NULL COMMENT 'KRW 또는 여행 통화',
    created_at     DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_budget_items_trip (trip_id),
    CONSTRAINT fk_budget_items_trip FOREIGN KEY (trip_id)
        REFERENCES trips (id) ON DELETE CASCADE,
    CONSTRAINT ck_budget_items_amount CHECK (amount >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- B. 지출
-- ---------------------------------------------------------------------
CREATE TABLE expenses (
    id                 BINARY(16)    NOT NULL,
    trip_id            BINARY(16)    NOT NULL,
    payer_member_id    BINARY(16)    NOT NULL,
    creator_member_id  BINARY(16)    NOT NULL COMMENT 'payer와 다르면 대리 입력',
    title              VARCHAR(100)  NOT NULL COMMENT '가게명 등',
    category           VARCHAR(20)   NOT NULL COMMENT 'budget_items.category 와 같은 코드',
    paid_date          DATE          NOT NULL,
    amount_local       DECIMAL(15,2) NULL COMMENT '여행 통화 금액. KRW 직접 입력 시 NULL',
    rate_mode          VARCHAR(10)   NOT NULL COMMENT 'API | PREPAID | MANUAL | KRW',
    applied_rate       DECIMAL(15,6) NULL COMMENT '저장 시점 스냅샷. KRW 모드면 NULL',
    rate_date          DATE          NULL COMMENT '실제 적용된 환율 날짜 (API 장애·주말 대비)',
    amount_krw         DECIMAL(15,0) NOT NULL COMMENT '최종 원화',
    split_method       VARCHAR(10)   NOT NULL COMMENT 'EQUAL | ITEM | CUSTOM',
    created_at         DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    version            INT           NOT NULL DEFAULT 0 COMMENT '낙관적 락',
    PRIMARY KEY (id),
    KEY idx_expenses_trip_date (trip_id, paid_date),
    KEY idx_expenses_trip_category (trip_id, category),
    KEY idx_expenses_payer (payer_member_id),
    KEY idx_expenses_creator (creator_member_id),
    CONSTRAINT fk_expenses_trip FOREIGN KEY (trip_id)
        REFERENCES trips (id) ON DELETE CASCADE,
    CONSTRAINT fk_expenses_payer FOREIGN KEY (payer_member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE,
    CONSTRAINT fk_expenses_creator FOREIGN KEY (creator_member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE,
    CONSTRAINT ck_expenses_rate_mode CHECK (rate_mode IN ('API', 'PREPAID', 'MANUAL', 'KRW')),
    CONSTRAINT ck_expenses_split CHECK (split_method IN ('EQUAL', 'ITEM', 'CUSTOM')),
    CONSTRAINT ck_expenses_amount CHECK (amount_krw >= 0),
    CONSTRAINT ck_expenses_krw_mode CHECK (
        (rate_mode = 'KRW' AND amount_local IS NULL AND applied_rate IS NULL)
        OR (rate_mode <> 'KRW' AND amount_local IS NOT NULL AND applied_rate IS NOT NULL)
    )
) ENGINE=InnoDB;

CREATE TABLE expense_items (
    id            BINARY(16)    NOT NULL,
    expense_id    BINARY(16)    NOT NULL,
    name          VARCHAR(100)  NOT NULL COMMENT 'EQUAL이면 항목 1개(총액)',
    amount_local  DECIMAL(15,2) NULL,
    amount_krw    DECIMAL(15,0) NOT NULL,
    sort_order    SMALLINT      NOT NULL,
    PRIMARY KEY (id),
    KEY idx_expense_items_expense (expense_id, sort_order),
    CONSTRAINT fk_expense_items_expense FOREIGN KEY (expense_id)
        REFERENCES expenses (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE expense_item_users (
    item_id    BINARY(16)    NOT NULL,
    member_id  BINARY(16)    NOT NULL,
    share_krw  DECIMAL(15,0) NOT NULL COMMENT '모든 분담 방식에서 계산 결과 저장 (원 단위 나머지는 결제자)',
    PRIMARY KEY (item_id, member_id),
    KEY idx_expense_item_users_member (member_id),
    CONSTRAINT fk_expense_item_users_item FOREIGN KEY (item_id)
        REFERENCES expense_items (id) ON DELETE CASCADE,
    CONSTRAINT fk_expense_item_users_member FOREIGN KEY (member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- B. 정산 (계산은 매번 실시간, 공유한 시점의 목록만 저장)
-- ---------------------------------------------------------------------
CREATE TABLE settlement_shares (
    id                   BINARY(16)  NOT NULL,
    trip_id              BINARY(16)  NOT NULL,
    shared_by_member_id  BINARY(16)  NOT NULL,
    created_at           DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_settlement_shares_trip (trip_id, created_at),
    KEY idx_settlement_shares_member (shared_by_member_id),
    CONSTRAINT fk_settlement_shares_trip FOREIGN KEY (trip_id)
        REFERENCES trips (id) ON DELETE CASCADE,
    CONSTRAINT fk_settlement_shares_member FOREIGN KEY (shared_by_member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE settlement_transfers (
    id              BINARY(16)    NOT NULL,
    share_id        BINARY(16)    NOT NULL,
    from_member_id  BINARY(16)    NOT NULL,
    to_member_id    BINARY(16)    NOT NULL,
    amount_krw      DECIMAL(15,0) NOT NULL,
    PRIMARY KEY (id),
    KEY idx_settlement_transfers_share (share_id),
    KEY idx_settlement_transfers_from (from_member_id),
    KEY idx_settlement_transfers_to (to_member_id),
    CONSTRAINT fk_settlement_transfers_share FOREIGN KEY (share_id)
        REFERENCES settlement_shares (id) ON DELETE CASCADE,
    CONSTRAINT fk_settlement_transfers_from FOREIGN KEY (from_member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE,
    CONSTRAINT fk_settlement_transfers_to FOREIGN KEY (to_member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE,
    CONSTRAINT ck_settlement_transfers_amount CHECK (amount_krw > 0)
) ENGINE=InnoDB;
