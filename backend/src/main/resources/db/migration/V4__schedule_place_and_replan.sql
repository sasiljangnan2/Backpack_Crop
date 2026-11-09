-- =====================================================================
-- V4: 일정 장소 좌표 · 분류 (지도 · 이동 시간, 스토리보드 BP-SC-001 · 004)
--     AI 재구성으로 바뀐 일정 표시 (BP-AI-003 "재구성" 배지)
-- =====================================================================

-- 좌표는 장소 검색(OpenStreetMap)에서 고른 값. 장소를 글자로만 적으면 비어 있다
ALTER TABLE schedules
    ADD COLUMN place_lat DECIMAL(9,6) NULL COMMENT '장소 위도'
        AFTER place_text;

ALTER TABLE schedules
    ADD COLUMN place_lng DECIMAL(9,6) NULL COMMENT '장소 경도'
        AFTER place_lat;

-- 재구성 조건(먹거리 · 실내 · 휴식)을 판단할 때 쓴다
ALTER TABLE schedules
    ADD COLUMN place_category VARCHAR(12) NULL COMMENT 'FOOD | CAFE | SHOPPING | SIGHT | PARK | LODGING | TRANSPORT | ETC'
        AFTER place_lng;

ALTER TABLE schedules
    ADD COLUMN replanned_at DATETIME(6) NULL COMMENT 'AI 재구성으로 바뀐 시각. 사람이 고치면 지운다'
        AFTER memo;

-- 위도와 경도는 함께 있거나 함께 없다
ALTER TABLE schedules
    ADD CONSTRAINT ck_schedules_place CHECK ((place_lat IS NULL) = (place_lng IS NULL));
