-- ============================================================
-- 객실 하자관리 시스템 - v26 입출고 이력 삭제 시 재고 자동 복원
-- 작성일: 2026-07-02
-- 실행 전 v25까지 적용되어 있어야 합니다.
--
-- 배경:
--   잘못 등록한 입고/출고 이력을 관리자가 삭제해도 재고 수량이
--   되돌아가지 않아 장부와 실물이 어긋났음.
--   → 삭제 시 수량 자동 복원. 이제 "잘못된 입고"의 올바른 정정은
--     관리자의 해당 이력 삭제이며, 입고 건수·재고가 함께 원복됨.
-- ============================================================

-- 1) 입고 이력 삭제 → 재고 감소 (해당 입고분이 이미 사용됐으면 차단)
create or replace function reverse_stock_in_on_delete()
returns trigger
security definer set search_path = public
as $$
declare
  v_stock integer;
begin
  select current_stock into v_stock from defect_parts where id = old.part_id for update;
  if v_stock is not null then
    if v_stock - old.quantity < 0 then
      raise exception '이 입고분이 이미 사용된 것으로 보여 삭제할 수 없습니다 (현재고 %개 < 입고 %개). 재고 실사/조정으로 수량을 맞춰주세요.', v_stock, old.quantity;
    end if;
    update defect_parts set current_stock = current_stock - old.quantity where id = old.part_id;
  end if;
  return old;
end;
$$ language plpgsql;

drop trigger if exists trg_reverse_stock_in on part_stock_in;
create trigger trg_reverse_stock_in
  before delete on part_stock_in
  for each row execute function reverse_stock_in_on_delete();

-- 2) 출고 이력 삭제 → 재고 복원
create or replace function reverse_stock_out_on_delete()
returns trigger
security definer set search_path = public
as $$
begin
  update defect_parts set current_stock = current_stock + old.quantity where id = old.part_id;
  return old;
end;
$$ language plpgsql;

drop trigger if exists trg_reverse_stock_out on part_stock_out;
create trigger trg_reverse_stock_out
  before delete on part_stock_out
  for each row execute function reverse_stock_out_on_delete();

-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 확인:
--   1. (admin) 테스트 입고 5개 등록 → 재고 +5 확인
--   2. 관리자 탭 > 재고이력에서 해당 입고 삭제 → 재고 -5 원복,
--      "이번달 입고 건수"도 감소하는지 확인
-- ============================================================
