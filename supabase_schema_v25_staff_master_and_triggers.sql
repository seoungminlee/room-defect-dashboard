-- ============================================================
-- 객실 하자관리 시스템 - v25 기준정보 staff 허용 + 재고 트리거 수정
-- 작성일: 2026-07-02
-- 실행 전 v24까지 적용되어 있어야 합니다.
--
-- 해결하는 문제:
--   1) 직원(staff)이 수리부속 단가 등 기준정보를 수정해도
--      DB가 admin 전용 정책으로 조용히 거부 (화면 에러 없음)
--      → 기준정보(객실타입·카테고리·부위·수리부속·발주설정)의
--        등록/수정을 staff에게 허용. 삭제는 admin 유지.
--   2) [중요] 재고 트리거가 호출자 권한으로 실행되어,
--      staff의 입고/출고/조정/부품사용 시 defect_parts.current_stock
--      갱신이 RLS에 막혀 조용히 누락될 수 있었음
--      → 트리거 함수를 security definer로 전환 (RLS와 무관하게 재고 갱신)
--
-- 유지되는 admin 전용: 직원 명단(employees), 외주업체(vendors),
--   삭제 전반, 데이터 초기화, 사용자 관리
-- ============================================================


-- ============================================================
-- 1) 기준정보 등록/수정 → staff·admin (삭제는 admin 유지)
-- ============================================================
drop policy if exists "ins_room_types" on room_types;
drop policy if exists "upd_room_types" on room_types;
create policy "ins_room_types" on room_types for insert with check (can_edit());
create policy "upd_room_types" on room_types for update using (can_edit());

drop policy if exists "ins_categories" on defect_categories;
drop policy if exists "upd_categories" on defect_categories;
create policy "ins_categories" on defect_categories for insert with check (can_edit());
create policy "upd_categories" on defect_categories for update using (can_edit());

drop policy if exists "ins_locations" on defect_locations;
drop policy if exists "upd_locations" on defect_locations;
create policy "ins_locations" on defect_locations for insert with check (can_edit());
create policy "upd_locations" on defect_locations for update using (can_edit());

drop policy if exists "ins_parts" on defect_parts;
drop policy if exists "upd_parts" on defect_parts;
create policy "ins_parts" on defect_parts for insert with check (can_edit());
create policy "upd_parts" on defect_parts for update using (can_edit());

drop policy if exists "upd_settings" on system_settings;
create policy "upd_settings" on system_settings for update using (can_edit());


-- ============================================================
-- 2) 재고 트리거 4종 — security definer로 전환
--    (호출자 권한이 아닌 시스템 권한으로 재고 수량 갱신)
-- ============================================================

-- 2-1) 입고 시 재고 증가
create or replace function apply_stock_in()
returns trigger
security definer set search_path = public
as $$
begin
  update defect_parts set current_stock = current_stock + new.quantity where id = new.part_id;
  return new;
end;
$$ language plpgsql;

-- 2-2) 일반 출고 시 재고 감소 (v22 재고 부족 가드 유지)
create or replace function apply_stock_out()
returns trigger
security definer set search_path = public
as $$
declare
  v_stock integer;
begin
  select current_stock into v_stock
  from defect_parts
  where id = new.part_id
  for update;

  if v_stock is null then
    raise exception '부속을 찾을 수 없습니다 (id=%)', new.part_id;
  end if;

  if v_stock < new.quantity then
    raise exception '재고 부족: 현재고 %개, 출고 요청 %개', v_stock, new.quantity;
  end if;

  update defect_parts
  set current_stock = current_stock - new.quantity
  where id = new.part_id;

  return new;
end;
$$ language plpgsql;

-- 2-3) 재고 실사 조정
create or replace function apply_stock_adjustment()
returns trigger
security definer set search_path = public
as $$
begin
  update defect_parts set current_stock = new.actual_stock where id = new.part_id;
  return new;
end;
$$ language plpgsql;

-- 2-4) 하자수리 부품 사용 시 재고 증감
create or replace function apply_stock_usage()
returns trigger
security definer set search_path = public
as $$
begin
  if (tg_op = 'INSERT') then
    if new.part_id is not null then
      update defect_parts set current_stock = current_stock - new.quantity where id = new.part_id;
    end if;
  elsif (tg_op = 'DELETE') then
    if old.part_id is not null then
      update defect_parts set current_stock = current_stock + old.quantity where id = old.part_id;
    end if;
  elsif (tg_op = 'UPDATE') then
    if old.part_id is not null then
      update defect_parts set current_stock = current_stock + old.quantity where id = old.part_id;
    end if;
    if new.part_id is not null then
      update defect_parts set current_stock = current_stock - new.quantity where id = new.part_id;
    end if;
  end if;
  return null;
end;
$$ language plpgsql;

-- 트리거 자체는 기존 것 그대로 사용 (함수 본문만 교체됨)


-- ============================================================
-- 3) 재고 수량 정합성 복구
--    과거 staff 입출고분이 재고에 반영 안 됐을 수 있으므로
--    이력 기준으로 현재고를 재계산
-- ============================================================
update defect_parts p
set current_stock = coalesce((
  -- 마지막 실사 조정 이후의 입출고만 반영
  select
    coalesce(adj.actual_stock, 0)
    + coalesce((select sum(quantity) from part_stock_in  where part_id = p.id and (adj.adjusted_at is null or received_at  > adj.adjusted_at)), 0)
    - coalesce((select sum(quantity) from part_stock_out where part_id = p.id and (adj.adjusted_at is null or released_at  > adj.adjusted_at)), 0)
    - coalesce((select sum(quantity) from defect_parts_used where part_id = p.id and (adj.adjusted_at is null or created_at > adj.adjusted_at)), 0)
  from (
    select actual_stock, adjusted_at
    from part_stock_adjustments
    where part_id = p.id
    order by adjusted_at desc
    limit 1
  ) adj
), (
  -- 실사 이력이 없으면 전체 입출고 합산
    coalesce((select sum(quantity) from part_stock_in  where part_id = p.id), 0)
  - coalesce((select sum(quantity) from part_stock_out where part_id = p.id), 0)
  - coalesce((select sum(quantity) from defect_parts_used where part_id = p.id), 0)
));


-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 실행 후 확인:
--   1. staff 계정으로 수리부속 단가 수정 → 저장되는지
--   2. staff 계정으로 입고 등록 → 현재고가 실제로 증가하는지
--   3. 재고 현황 수량이 실물과 맞는지 (3번 재계산 결과 확인,
--      다르면 재고 실사/조정으로 맞추면 됨)
-- ============================================================
