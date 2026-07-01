-- ============================================================
-- 객실 하자관리 시스템 - v4 추가 스키마 (부품 재고관리)
-- 작성일: 2026-06-23
-- 설명: 기존 v1~v3 스키마는 그대로 두고 이 파일만 추가로 실행하세요.
--       기존 데이터는 건드리지 않고 새 컬럼/테이블만 추가합니다.
--
-- 범위: 하자수리에 쓰는 부품만 관리합니다. 청소용품 등 일반 소모품은
--       별도 소모품 관리 프로그램에서 관리하므로 이 시스템 범위가 아닙니다.
-- ============================================================

-- ------------------------------------------------------------
-- 1) defect_parts 테이블에 재고관리 필드 추가
-- ------------------------------------------------------------
alter table defect_parts add column if not exists current_stock numeric(10,2) not null default 0;          -- 현재고
alter table defect_parts add column if not exists expected_monthly_usage numeric(10,2) not null default 0; -- 등록 초기 3개월간 사용할 예상 월평균 사용량 (직접 입력)
alter table defect_parts add column if not exists registered_at timestamptz not null default now();        -- 평균사용량 전환 기준일 (이 날로부터 3개월 경과 여부 판단)
alter table defect_parts add column if not exists safety_factor numeric(4,2);                              -- 부품별 안전계수 오버라이드 (NULL이면 전체공통값 사용)

-- ------------------------------------------------------------
-- 2) 부품 입고 이력
-- ------------------------------------------------------------
create table if not exists part_stock_in (
  id bigint generated always as identity primary key,
  part_id bigint not null references defect_parts(id) on delete cascade,
  quantity numeric(10,2) not null,
  unit_price numeric(12,2) not null default 0,   -- 입고 당시 단가 (총금액 계산용, 과거 기록 보존)
  total_cost numeric(14,2) generated always as (quantity * unit_price) stored,
  received_by text,                               -- 입고자 (자유텍스트 — 로그인 기능 도입 전까지는 직접 입력)
  note text,
  received_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 3) 부품 일반 출고 이력 (하자수리 외 사유 — 폐기, 분실, 타지점 이동 등)
--    하자수리에 쓴 부품은 defect_parts_used에 이미 기록되며, 그 트리거가
--    재고를 별도로 차감하므로 여기서는 다루지 않습니다 (아래 4번 참고).
-- ------------------------------------------------------------
create table if not exists part_stock_out (
  id bigint generated always as identity primary key,
  part_id bigint not null references defect_parts(id) on delete cascade,
  quantity numeric(10,2) not null,
  reason text,                                    -- 출고 사유 (예: 폐기, 분실, 타지점 이동)
  released_by text,                                -- 출고자 (자유텍스트)
  note text,
  released_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 4) 재고 실사/조정 이력
--    시스템 재고와 실제 현물 재고가 어긋났을 때, 실사 후 차이를 보정합니다.
-- ------------------------------------------------------------
create table if not exists part_stock_adjustments (
  id bigint generated always as identity primary key,
  part_id bigint not null references defect_parts(id) on delete cascade,
  before_stock numeric(10,2) not null,            -- 조정 전 시스템 재고
  actual_stock numeric(10,2) not null,            -- 실사로 확인한 실제 재고
  diff numeric(10,2) generated always as (actual_stock - before_stock) stored,
  reason text,                                     -- 조정 사유
  adjusted_by text,                                -- 실사자 (자유텍스트)
  adjusted_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 5) 재고 자동 갱신 트리거
--    입고/일반출고/재고조정/하자수리사용 네 가지 이벤트가 모두
--    defect_parts.current_stock에 자동 반영됩니다.
-- ------------------------------------------------------------

-- 5-1) 입고 시 재고 증가
create or replace function apply_stock_in()
returns trigger as $$
begin
  update defect_parts set current_stock = current_stock + new.quantity where id = new.part_id;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_apply_stock_in on part_stock_in;
create trigger trg_apply_stock_in
  after insert on part_stock_in
  for each row execute function apply_stock_in();

-- 5-2) 일반 출고 시 재고 감소
create or replace function apply_stock_out()
returns trigger as $$
begin
  update defect_parts set current_stock = current_stock - new.quantity where id = new.part_id;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_apply_stock_out on part_stock_out;
create trigger trg_apply_stock_out
  after insert on part_stock_out
  for each row execute function apply_stock_out();

-- 5-3) 재고 실사 조정 시 시스템 재고를 실사값으로 맞춤
create or replace function apply_stock_adjustment()
returns trigger as $$
begin
  update defect_parts set current_stock = new.actual_stock where id = new.part_id;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_apply_stock_adjustment on part_stock_adjustments;
create trigger trg_apply_stock_adjustment
  after insert on part_stock_adjustments
  for each row execute function apply_stock_adjustment();

-- 5-4) 하자수리에 부품 사용 시 재고 감소 (defect_parts_used는 이미 v2에서 만들어졌으므로
--      재고 차감 트리거만 추가로 얹습니다. 기존 비용 합산 트리거와는 별개로 동작합니다.)
create or replace function apply_stock_usage()
returns trigger as $$
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

drop trigger if exists trg_apply_stock_usage on defect_parts_used;
create trigger trg_apply_stock_usage
  after insert or update or delete on defect_parts_used
  for each row execute function apply_stock_usage();

-- ------------------------------------------------------------
-- 6) 전체공통 안전계수 설정 (시스템 설정값 1개를 두는 작은 테이블)
-- ------------------------------------------------------------
create table if not exists system_settings (
  key text primary key,
  value text not null
);

insert into system_settings (key, value) values ('parts_safety_factor', '1.5')
on conflict (key) do nothing;

-- ------------------------------------------------------------
-- 7) RLS 정책
-- ------------------------------------------------------------
alter table part_stock_in enable row level security;
alter table part_stock_out enable row level security;
alter table part_stock_adjustments enable row level security;
alter table system_settings enable row level security;

create policy "anon_select_stock_in" on part_stock_in for select using (true);
create policy "anon_insert_stock_in" on part_stock_in for insert with check (true);
create policy "anon_delete_stock_in" on part_stock_in for delete using (true);

create policy "anon_select_stock_out" on part_stock_out for select using (true);
create policy "anon_insert_stock_out" on part_stock_out for insert with check (true);
create policy "anon_delete_stock_out" on part_stock_out for delete using (true);

create policy "anon_select_adjustments" on part_stock_adjustments for select using (true);
create policy "anon_insert_adjustments" on part_stock_adjustments for insert with check (true);

create policy "anon_select_settings" on system_settings for select using (true);
create policy "anon_update_settings" on system_settings for update using (true);

-- ============================================================
-- 끝. 여기까지 SQL Editor에 붙여넣고 Run 누르세요.
--
-- 참고: 평균사용량 계산 로직(등록일로부터 3개월 경과 여부 판단, 최근 3개월
-- 이동평균 계산)은 매번 바뀌는 "오늘 날짜" 기준 계산이라 DB 컬럼으로 고정
-- 저장하지 않고, 사이트(JS) 쪽에서 매번 조회 시점에 계산합니다.
-- ============================================================
