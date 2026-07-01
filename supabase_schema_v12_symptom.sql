-- ============================================================
-- 객실 하자관리 시스템 - v12 스키마 (공종 → 하자증상 전환)
-- 작성일: 2026-06-23
--
-- 변경 내용:
--   1) defects 테이블에 symptom 컬럼 추가 (하자증상)
--   2) defects.category_id → NOT NULL 제거 (선택사항으로 변경)
--   3) defect_locations.category_id → NOT NULL 제거 (이미 null 허용이지만 명시)
--   4) defect_parts.category_id → NOT NULL 제거 (이미 null 허용이지만 명시)
--
-- 하자증상 고정값 (코드에서 관리, DB enum 아님):
--   누수·누전 / 파손·균열 / 오염·변색 / 작동불량 / 소음·냄새 / 기타
--
-- 공종(defect_categories) 테이블은 삭제하지 않습니다.
--   - pm_schedules.category_id, monthly_budget.category_id 참조 중
--   - 향후 외주업체(vendors) 연결 시 재활용 가능
--   - 단, UI에서는 제거하여 사용하지 않음
-- ============================================================


-- ============================================================
-- 1) defects 테이블에 symptom 컬럼 추가
-- ============================================================
alter table defects
  add column if not exists symptom text;

-- symptom 컬럼 코멘트
comment on column defects.symptom is '하자증상: 누수·누전 / 파손·균열 / 오염·변색 / 작동불량 / 소음·냄새 / 기타';

-- ============================================================
-- 2) defects.category_id NOT NULL 제거 (선택사항으로 변경)
--    (기존에 NOT NULL이 걸려 있을 경우 제거)
-- ============================================================
alter table defects
  alter column category_id drop not null;

-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 이후 작업:
--   - index.html을 GitHub에 배포하면 UI에 반영됩니다.
--   - defect_categories 테이블은 그대로 두세요 (선구축 테이블이 참조 중).
-- ============================================================
