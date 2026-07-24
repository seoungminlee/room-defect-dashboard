-- ============================================================
-- 객실 하자관리 시스템 - v31 하자 총비용 재계산 트리거 하드닝
-- 작성일: 2026-07-09
-- 실행 전 v30까지 적용되어 있어야 합니다.
--
-- 배경:
--   "사용 부속/발생비용 저장 후 목록에 반영 안 됨" 신고 조사 중 발견.
--   defects.total_cost를 자동 갱신하는 recalc_defect_total_cost() 트리거가
--   v2에서 처음 만들어진 이후 한 번도 security definer로 전환되지 않았음
--   (재고 트리거 4종은 v25에서 이미 전환됨 — 이 트리거만 누락됨).
--
--   invoker 권한으로 실행되면, defect_parts_used insert를 수행한 사용자의
--   RLS 컨텍스트로 defects.total_cost update가 실행됨. 현재 정책상으로는
--   staff·admin 모두 통과하는 것이 정상이지만, 세션/토큰 상태에 따라
--   재고 트리거와 동일한 클래스의 실패가 재현될 수 있어 동일한 기준으로
--   맞춰 안전하게 만듭니다. (근본 원인이 이것이 아니었다면, 코드 쪽에
--   추가된 에러 표시 로직으로 정확한 원인이 화면에 나타납니다.)
-- ============================================================

create or replace function recalc_defect_total_cost()
returns trigger
security definer set search_path = public
as $$
declare
  target_defect_id bigint;
  new_total numeric;
begin
  target_defect_id := coalesce(new.defect_id, old.defect_id);
  select coalesce(sum(quantity*unit_price + coalesce(labor_cost,0)), 0)
    into new_total
    from defect_parts_used
    where defect_id = target_defect_id;
  update defects set total_cost = new_total where id = target_defect_id;
  return null;
end;
$$ language plpgsql;

-- 트리거 자체는 기존 것 그대로 사용 (함수 본문만 교체됨, v25와 동일한 방식)

-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 실행 후 확인:
--   기존 하자에 사용 부속/비용을 추가 → 저장 → 목록의 발생비용 컬럼과
--   상세보기에 정상 반영되는지 확인.
-- ============================================================
