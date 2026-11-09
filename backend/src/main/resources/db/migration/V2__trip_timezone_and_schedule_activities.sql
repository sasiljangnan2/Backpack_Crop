-- =====================================================================
-- V2: 여행 현지 시간대 + 일정 활동 기록 (오늘 요약 · 지연 계산용)
-- =====================================================================

-- 일정의 day / start_time / end_time은 여행지 현지 시각이다.
-- "지금 진행 중인 일정", "다음 고정 일정까지 남은 시간"을 계산하려면 현지 시간대가 필요하다
ALTER TABLE trips
    ADD COLUMN time_zone VARCHAR(40) NOT NULL DEFAULT 'Asia/Seoul'
        COMMENT 'IANA 시간대 (예: Asia/Tokyo). 일정 시각의 기준'
        AFTER currency_code;

-- 일정 하나에 기록 하나 (다시 기록하면 덮어쓴다). 기록이 있으면 그 일정은 완료(DONE)다
CREATE TABLE schedule_activities (
    id                     BINARY(16)  NOT NULL,
    schedule_id            BINARY(16)  NOT NULL,
    recorded_by_member_id  BINARY(16)  NOT NULL,
    actual_start_time      TIME        NOT NULL COMMENT '현지 시각',
    actual_end_time        TIME        NOT NULL COMMENT '현지 시각',
    delay_min              INT         NOT NULL COMMENT '실제 종료 − 계획 종료(분). 일찍 끝나면 0',
    created_at             DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at             DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_schedule_activities_schedule (schedule_id),
    KEY idx_schedule_activities_member (recorded_by_member_id),
    CONSTRAINT fk_schedule_activities_schedule FOREIGN KEY (schedule_id)
        REFERENCES schedules (id) ON DELETE CASCADE,
    CONSTRAINT fk_schedule_activities_member FOREIGN KEY (recorded_by_member_id)
        REFERENCES trip_members (id) ON DELETE CASCADE,
    CONSTRAINT ck_schedule_activities_time CHECK (actual_end_time >= actual_start_time),
    CONSTRAINT ck_schedule_activities_delay CHECK (delay_min >= 0)
) ENGINE=InnoDB;
