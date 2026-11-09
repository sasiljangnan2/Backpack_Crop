-- =====================================================================
-- V5: 지출 내용 · 항목 이름의 한국어 번역 (영수증 읽기, 스토리보드 BP-EX-003)
--     외국어 영수증에서 읽은 가게 · 상품 이름 밑에 한국어를 보여 준다
-- =====================================================================

-- 원문이 한국어거나 직접 입력한 지출이면 비어 있다
ALTER TABLE expenses
    ADD COLUMN title_ko VARCHAR(100) NULL COMMENT '내용(가게 이름)의 한국어 번역'
        AFTER title;

ALTER TABLE expense_items
    ADD COLUMN name_ko VARCHAR(100) NULL COMMENT '항목 이름의 한국어 번역'
        AFTER name;
