-- ============================================================
-- 객실 하자관리 시스템 - v22 출고 재고 검증 (DB 차원)
-- 작성일: 2026-07-02
-- 실행 전 v21까지 적용되어 있어야 합니다.
--
-- 내용:
--   일반 출고(part_stock_out) 시 현재고를 초과하면 DB에서 거부.
--   화면(index.html)에도 같은 검증이 있지만, API 직접 호출이나
--   동시 입력 상황까지 막으려면 DB 차원 방어가 필요함.
--   (하자수리 부품 사용은 수리 기록 차단 부작용을 피하기 위해 제외)
-- ============================================================

create or replace function apply_stock_out()
returns trigger as $$
declare
  v_stock integer;
begin
  select current_stock into v_stock
  from defect_parts
  where id = new.part_id
  for update;   -- 동시 출고 경합 방지

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

-- 트리거는 기존 것(v4) 그대로 사용 — 함수 본문만 교체됨


-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 실행 후 확인:
--   현재고보다 많은 수량으로 일반 출고 시도 → "재고 부족" 에러로 거부
-- ============================================================
