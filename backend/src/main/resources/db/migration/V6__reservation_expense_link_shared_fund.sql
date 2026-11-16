-- =====================================================================
-- V6: 일정 예약 정보 (BP-SC-001 · 002) · 지출-일정 연결 (BP-SC-003) · 공금
-- =====================================================================

-- 예약 시간과 "예약 전" 상태 (NONE = 예약 없음)
ALTER TABLE schedules
    ADD COLUMN reservation_time TIME NULL COMMENT '예약 시간. 예약이 없으면 NULL'
        AFTER reservation_status;

ALTER TABLE schedules DROP CHECK ck_schedules_reservation;

ALTER TABLE schedules
    ADD CONSTRAINT ck_schedules_reservation
        CHECK (reservation_status IN ('NONE', 'BEFORE', 'PENDING', 'CONFIRMED'));

-- 예약 결제를 등록한 지출은 일정과 잇는다. 일정을 지워도 지출은 남는다
-- paid_from_fund: 공금에서 낸 지출. 이때 payer_member_id는 입력한 사람이고 정산에서 낸 돈으로 치지 않는다
ALTER TABLE expenses
    ADD COLUMN schedule_id BINARY(16) NULL COMMENT '연결된 일정'
        AFTER trip_id,
    ADD COLUMN paid_from_fund BOOLEAN NOT NULL DEFAULT FALSE COMMENT '공금에서 낸 지출'
        AFTER payer_member_id,
    ADD KEY idx_expenses_schedule (schedule_id),
    ADD CONSTRAINT fk_expenses_schedule FOREIGN KEY (schedule_id)
        REFERENCES schedules (id) ON DELETE SET NULL;

-- 공금: 멤버가 모은 돈. 원화로 기록한다
CREATE TABLE fund_contributions (
    id                 BINARY(16)    NOT NULL,
    trip_id            BINARY(16)    NOT NULL,
    member_id          BINARY(16)    NOT NULL COMMENT '돈을 낸 사람',
    creator_member_id  BINARY(16)    NOT NULL COMMENT '입력한 사람',
    amount_krw         DECIMAL(15,0) NOT NULL,
    contributed_on     DATE          NOT NULL,
    memo               VARCHAR(100)  NULL,
    created_at         DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_fund_contributions_trip (trip_id, contributed_on),
    KEY idx_fund_contributions_member (member_id),
    KEY idx_fund_contributions_creator (creator_member_id),
    CONSTRAINT fk_fund_contributions_trip FOREIGN KEY (trip_id)
        REFERENCES trips (id) ON DELETE CASCADE,
    CONSTRAINT fk_fund_contributions_member FOREIGN KEY (member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE,
    CONSTRAINT fk_fund_contributions_creator FOREIGN KEY (creator_member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE,
    CONSTRAINT ck_fund_contributions_amount CHECK (amount_krw > 0)
) ENGINE=InnoDB;

-- 정산 공유 기록에서 NULL = 공금 (남은 공금 돌려받기 · 모자란 공금 채우기)
ALTER TABLE settlement_transfers
    MODIFY from_member_id BINARY(16) NULL,
    MODIFY to_member_id   BINARY(16) NULL;
