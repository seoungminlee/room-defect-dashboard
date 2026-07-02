-- ============================================================
-- 객실 하자관리 시스템 - v28 자체 감사 후속 정리
-- 작성일: 2026-07-02
--
-- 내용:
--   1) v25의 재고 재계산 쿼리 재작성 (문법 오류 가능성 있던 패턴 제거)
--      ★ v25 실행 시 에러가 났었다면 이 파일이 그 부분을 대체함.
--        v25가 정상 실행됐어도 중복 실행 무해 (이력 기준 재계산).
--   2) security definer 함수 search_path 고정 (v21에서 누락된 하드닝)
-- ============================================================


-- ============================================================
-- 1) 재고 수량 재계산 (안전한 스칼라 서브쿼리 방식)
--    마지막 실사 조정값 + 그 이후의 입고 - 출고 - 부품사용
-- ============================================================
update defect_parts p
set current_stock =
  coalesce((
    select a.actual_stock from part_stock_adjustments a
    where a.part_id = p.id
    order by a.adjusted_at desc limit 1
  ), 0)
  + coalesce((
    select sum(s.quantity) from part_stock_in s
    where s.part_id = p.id
      and s.received_at > coalesce(
        (select max(a.adjusted_at) from part_stock_adjustments a where a.part_id = p.id),
        '-infinity'::timestamptz)
  ), 0)
  - coalesce((
    select sum(s.quantity) from part_stock_out s
    where s.part_id = p.id
      and s.released_at > coalesce(
        (select max(a.adjusted_at) from part_stock_adjustments a where a.part_id = p.id),
        '-infinity'::timestamptz)
  ), 0)
  - coalesce((
    select sum(u.quantity) from defect_parts_used u
    where u.part_id = p.id
      and u.created_at > coalesce(
        (select max(a.adjusted_at) from part_stock_adjustments a where a.part_id = p.id),
        '-infinity'::timestamptz)
  ), 0);


-- ============================================================
-- 2) security definer 함수 search_path 고정 (하드닝)
-- ============================================================
alter function audit_row_change() set search_path = public;
alter function get_my_role() set search_path = public;
alter function can_edit() set search_path = public;
alter function admin_list_users() set search_path = public;
alter function admin_set_user_role(text, text) set search_path = public;
alter function admin_reset_user_password(text, text) set search_path = public;
alter function reset_operation_data(text) set search_path = public;


-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- ★ 중요: v25 실행 당시 에러가 났었다면 (아무 메시지 없이 Success가
--   아니었다면) v25를 다시 열어 1)·2)번 섹션만 실행하세요.
--   (3번 재계산 섹션은 이 파일이 대체함)
--
-- 확인:
--   재고 현황 수량이 입출고 이력과 일치하는지 확인
-- ============================================================
