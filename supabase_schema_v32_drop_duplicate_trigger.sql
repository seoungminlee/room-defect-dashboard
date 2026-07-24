-- ============================================================
-- 객실 하자관리 시스템 - v32 중복/오작동 트리거 제거
-- 작성일: 2026-07-09
-- 실행 전 v31까지 적용되어 있어야 합니다.
--
-- 확정된 근본 원인:
--   defect_parts_used 테이블에 recalc_defect_total_cost()(정상, v2/v31)
--   외에 sync_defect_total_cost()라는 트리거가 하나 더 붙어 있었음.
--   이 함수는 로컬 SQL 파일 이력에 없는 것으로 보아 대시보드에서
--   직접 생성됐거나 다른 프로젝트 작업이 실수로 이 프로젝트에
--   적용된 것으로 추정됨.
--
--   결정적으로 이 함수 내부에서 v_defect_id 변수를 uuid로 선언했는데
--   실제 defect_id는 bigint라서, 부속/비용을 추가할 때마다
--   "invalid input syntax for type uuid" 오류로 INSERT 전체가
--   롤백되고 있었음 (화면엔 부속이 추가된 것처럼 보였다가 저장 시
--   조용히 사라지는 현상의 정확한 원인).
--
--   recalc_defect_total_cost()가 이미 동일한 역할을 정상 수행하므로
--   이 중복 트리거/함수는 삭제합니다.
-- ============================================================

drop trigger if exists trg_sync_defect_total_cost on defect_parts_used;
drop function if exists sync_defect_total_cost();

-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 실행 후 확인:
--   1. 아래 쿼리 결과에 trg_sync_defect_total_cost가 더 이상 없는지 확인
--      select tgname from pg_trigger
--      where tgrelid = 'defect_parts_used'::regclass and not tgisinternal;
--   2. 하자에 사용 부속/비용 추가 → 저장 → 목록/상세 모두 정상 반영되는지 확인
-- ============================================================
