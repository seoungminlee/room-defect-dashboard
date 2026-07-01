-- ============================================================
-- 객실 하자관리 시스템 - v2 추가 스키마 (기준정보/마스터 데이터)
-- 작성일: 2026-06-23
-- 설명: 기존에 실행한 supabase_schema.sql은 그대로 두고,
--       이 파일만 SQL Editor에 추가로 붙여넣고 실행하세요.
--       기존 데이터(객실, 하자)는 건드리지 않고 새 테이블/컬럼만 추가합니다.
-- ============================================================

-- ------------------------------------------------------------
-- 1) 객실타입 마스터
-- 예: 스튜디오 로프트, 패밀리 투룸 오션 등을 미리 등록해두는 표
-- ------------------------------------------------------------
create table if not exists room_types (
  id bigint generated always as identity primary key,
  name text not null unique,         -- 예: 스튜디오 로프트
  description text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- rooms 테이블에 room_type_id 컬럼 추가 (기존 room_type 텍스트 컬럼은 유지, 병행 운영)
alter table rooms add column if not exists room_type_id bigint references room_types(id);

-- ------------------------------------------------------------
-- 2) 하자부위 마스터
-- 예: 화장실 벽면, 침대 헤드보드, 발코니 바닥 등 "어디서" 하자가 났는지
-- ------------------------------------------------------------
create table if not exists defect_locations (
  id bigint generated always as identity primary key,
  name text not null unique,         -- 예: 화장실 벽면, 침실 바닥
  category_id bigint references defect_categories(id),  -- 어느 공종과 주로 연결되는지 (선택)
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- defects 테이블에 location_id 컬럼 추가
alter table defects add column if not exists location_id bigint references defect_locations(id);

-- ------------------------------------------------------------
-- 3) 수리부속(자재) 마스터 - 단가 포함
-- 예: 변기 시트, 도어락 본체, 타일(개당) 등 자주 쓰는 부품과 표준 단가
-- ------------------------------------------------------------
create table if not exists defect_parts (
  id bigint generated always as identity primary key,
  name text not null unique,          -- 예: 변기 시트, 도어락 본체
  category_id bigint references defect_categories(id),  -- 어느 공종 부품인지
  unit text not null default '개',     -- 단위: 개, m, set 등
  unit_price numeric(12,2) not null default 0,  -- 표준 단가 (원)
  vendor_name text,                    -- 주 거래처 (선택)
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 4) 하자별 사용 부품 / 발생비용 기록
-- 하자 한 건에 부품을 여러 개 쓸 수 있으므로 별도 표로 분리
-- ------------------------------------------------------------
create table if not exists defect_parts_used (
  id bigint generated always as identity primary key,
  defect_id bigint not null references defects(id) on delete cascade,
  part_id bigint references defect_parts(id),   -- 마스터에 없는 자재면 null + 직접입력 사용
  part_name_manual text,              -- 마스터에 없는 부품을 직접 적을 때
  quantity numeric(10,2) not null default 1,
  unit_price numeric(12,2) not null default 0,  -- 등록 시점 단가 (마스터 단가가 바뀌어도 과거 기록 보존)
  labor_cost numeric(12,2) not null default 0,  -- 인건비 (선택)
  note text,
  created_at timestamptz not null default now()
);

create index if not exists idx_parts_used_defect on defect_parts_used(defect_id);

-- defects 테이블에 총비용을 빠르게 보여주기 위한 합계 컬럼 (조회 편의용 - 트리거로 자동 갱신)
alter table defects add column if not exists total_cost numeric(12,2) not null default 0;

create or replace function recalc_defect_total_cost()
returns trigger as $$
declare
  target_defect_id bigint;
  new_total numeric(12,2);
begin
  target_defect_id := coalesce(new.defect_id, old.defect_id);
  select coalesce(sum(quantity * unit_price + labor_cost), 0)
    into new_total
    from defect_parts_used
    where defect_id = target_defect_id;
  update defects set total_cost = new_total where id = target_defect_id;
  return null;
end;
$$ language plpgsql;

drop trigger if exists trg_recalc_cost_ins on defect_parts_used;
create trigger trg_recalc_cost_ins
  after insert or update or delete on defect_parts_used
  for each row execute function recalc_defect_total_cost();

-- ------------------------------------------------------------
-- 5) RLS 정책 (기존과 동일하게 anon 전체 허용 - 내부 도구용)
-- ------------------------------------------------------------
alter table room_types enable row level security;
alter table defect_locations enable row level security;
alter table defect_parts enable row level security;
alter table defect_parts_used enable row level security;

create policy "anon_select_room_types" on room_types for select using (true);
create policy "anon_insert_room_types" on room_types for insert with check (true);
create policy "anon_update_room_types" on room_types for update using (true);
create policy "anon_delete_room_types" on room_types for delete using (true);

create policy "anon_select_locations" on defect_locations for select using (true);
create policy "anon_insert_locations" on defect_locations for insert with check (true);
create policy "anon_update_locations" on defect_locations for update using (true);
create policy "anon_delete_locations" on defect_locations for delete using (true);

create policy "anon_select_parts" on defect_parts for select using (true);
create policy "anon_insert_parts" on defect_parts for insert with check (true);
create policy "anon_update_parts" on defect_parts for update using (true);
create policy "anon_delete_parts" on defect_parts for delete using (true);

create policy "anon_select_parts_used" on defect_parts_used for select using (true);
create policy "anon_insert_parts_used" on defect_parts_used for insert with check (true);
create policy "anon_update_parts_used" on defect_parts_used for update using (true);
create policy "anon_delete_parts_used" on defect_parts_used for delete using (true);

-- ------------------------------------------------------------
-- 6) 기본 마스터 데이터 (예시 - 필요시 사이트의 '기준정보 관리' 화면에서 수정/추가 가능)
-- ------------------------------------------------------------
insert into room_types (name, sort_order) values
  ('스튜디오 로프트', 1),
  ('스튜디오 로프트 서프', 2),
  ('패밀리 투룸 오션', 3),
  ('프리미어 스위트 패밀리', 4)
on conflict (name) do nothing;

insert into defect_locations (name, sort_order) values
  ('화장실 벽면', 1),
  ('화장실 바닥', 2),
  ('침실 벽면', 3),
  ('침실 바닥', 4),
  ('거실 벽면', 5),
  ('발코니', 6),
  ('주방', 7),
  ('현관·도어', 8),
  ('기타', 9)
on conflict (name) do nothing;

-- ============================================================
-- 끝. 여기까지 SQL Editor에 붙여넣고 Run 누르세요.
-- ============================================================
