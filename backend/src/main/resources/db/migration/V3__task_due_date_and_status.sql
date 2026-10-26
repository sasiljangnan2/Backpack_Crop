-- =====================================================================
-- V3: 준비 업무 마감일 · 진행 상태 (스토리보드 BP-PR-001 · 002)
-- =====================================================================

-- 마감일: 함께 할 업무는 앱에서 필수로 받고, 개인 준비물은 비워 둘 수 있다
ALTER TABLE tasks
    ADD COLUMN due_date DATE NULL COMMENT '마감일 (여행지 날짜)'
        AFTER title;

-- 진행 상태: 할 일 → 진행 중 → 완료. is_done은 status = DONE과 같게 유지한다 (기존 조회 호환)
ALTER TABLE tasks
    ADD COLUMN status VARCHAR(12) NOT NULL DEFAULT 'TODO' COMMENT 'TODO | IN_PROGRESS | DONE'
        AFTER due_date;

UPDATE tasks SET status = 'DONE' WHERE is_done = TRUE;

ALTER TABLE tasks
    ADD CONSTRAINT ck_tasks_status CHECK (status IN ('TODO', 'IN_PROGRESS', 'DONE'));
