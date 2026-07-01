-- ============================================================
-- 객실 하자관리 시스템 - v6 추가 스키마 (외주 처리비 단일입력)
-- 작성일: 2026-06-23
-- 설명: 기존 v1~v5 스키마는 그대로 두고 이 파일만 추가로 실행하세요.
--
-- 배경: 자체처리는 부속을 하나씩 골라 합산하지만, 외주업체는 부품 내역을
--       공개하지 않고 "출장비+수리비 얼마"로만 청구하는 경우가 많습니다.
--       그래서 처리방식이 외주일 때는 부속 합산 대신 "외주 처리비" 한 값을
--       직접 입력받아 total_cost로 사용하도록 분기합니다.
-- ============================================================

-- ------------------------------------------------------------
-- 1) defects에 외주 처리비 컬럼 추가
-- ------------------------------------------------------------
alter table defects add column if not exists outsourced_cost numeric(12,2) not null default 0;

-- ------------------------------------------------------------
-- 2) total_cost 계산 로직 분기
--    - is_outsourced = true  -> total_cost = outsourced_cost (부속 합산 무시)
--    - is_outsourced = false -> total_cost = defect_parts_used 합산 (기존 방식)
-- ------------------------------------------------------------
create or replace function recalc_defect_total_cost_for(target_defect_id bigint)
returns void as $$
declare
  v_is_outsourced boolean;
  v_outsourced_cost numeric(12,2);
  v_parts_sum numeric(12,2);
begin
  select is_outsourced, outsourced_cost into v_is_outsourced, v_outsourced_cost
  from defects where id = target_defect_id;

  if v_is_outsourced then
    update defects set total_cost = coalesce(v_outsourced_cost, 0) where id = target_defect_id;
  else
    select coalesce(sum(quantity * unit_price + labor_cost), 0) into v_parts_sum
    from defect_parts_used where defect_id = target_defect_id;
    update defects set total_cost = v_parts_sum where id = target_defect_id;
  end if;
end;
$$ language plpgsql;

-- defect_parts_used 변경 시 (기존 트리거 함수를 새 분기 로직으로 교체)
create or replace function recalc_defect_total_cost()
returns trigger as $$
declare
  target_defect_id bigint;
begin
  target_defect_id := coalesce(new.defect_id, old.defect_id);
  perform recalc_defect_total_cost_for(target_defect_id);
  return null;
end;
$$ language plpgsql;
-- (트리거 자체는 v2에서 이미 생성됨 - 함수 내용만 교체되어 자동 반영됩니다)

-- defects.is_outsourced 또는 outsourced_cost가 직접 바뀔 때(또는 처음 등록될 때)도 재계산
-- INSERT와 UPDATE 모두에 적용되어, 새 하자를 외주로 등록하는 순간에도 total_cost가 바로 채워집니다.
create or replace function recalc_total_cost_on_defect_change()
returns trigger as $$
begin
  if (tg_op = 'INSERT') or (new.is_outsourced is distinct from old.is_outsourced) or (new.outsourced_cost is distinct from old.outsourced_cost) then
    if new.is_outsourced then
      new.total_cost := coalesce(new.outsourced_cost, 0);
    else
      select coalesce(sum(quantity * unit_price + labor_cost), 0) into new.total_cost
      from defect_parts_used where defect_id = new.id;
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_recalc_cost_on_defect_change on defects;
create trigger trg_recalc_cost_on_defect_change
  before insert or update on defects
  for each row execute function recalc_total_cost_on_defect_change();

-- ============================================================
-- 끝. 여기까지 SQL Editor에 붙여넣고 Run 누르세요.
-- ============================================================
