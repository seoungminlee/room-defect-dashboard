-- ============================================================
-- 객실 하자관리 시스템 - Supabase 스키마
-- 작성일: 2026-06-23
-- 설명: 이 SQL 전체를 Supabase 대시보드 > SQL Editor에 붙여넣고
--       "Run" 버튼을 누르면 표(테이블)가 한 번에 만들어집니다.
-- ============================================================

-- 1) 객실 테이블
-- 지점의 객실 목록. 처음 한 번만 등록해두면 계속 재사용합니다.
create table if not exists rooms (
  id bigint generated always as identity primary key,
  room_number text not null unique,      -- 예: 705
  floor text,                             -- 예: 7F
  room_type text,                         -- 예: 스튜디오 로프트
  created_at timestamptz not null default now()
);

-- 2) 공종 카테고리 테이블
-- 목공/전기/설비 등 하자를 분류하는 기준. 필요하면 직접 추가/수정 가능.
create table if not exists defect_categories (
  id bigint generated always as identity primary key,
  name text not null unique,              -- 예: 목공, 전기·조명
  sort_order int not null default 0,       -- 화면에 표시할 순서
  created_at timestamptz not null default now()
);

insert into defect_categories (name, sort_order) values
  ('목공', 1),
  ('전기·조명', 2),
  ('설비·배관', 3),
  ('도장·마감', 4),
  ('타일·욕실', 5),
  ('도어·하드웨어', 6),
  ('가전', 7),
  ('바닥재', 8),
  ('기타', 9)
on conflict (name) do nothing;

-- 3) 하자 테이블 (핵심 테이블)
-- 객실에서 발견된 하자 한 건 한 건이 여기 한 줄씩 쌓입니다.
create table if not exists defects (
  id bigint generated always as identity primary key,
  room_id bigint not null references rooms(id) on delete cascade,
  category_id bigint not null references defect_categories(id),
  title text not null,                    -- 예: 화장실 타일 깨짐
  description text,                       -- 상세 설명
  status text not null default '접수'
    check (status in ('접수', '확인', '조치중', '완료')),
  is_outsourced boolean not null default false,  -- 외주 처리 여부 (true=외주, false=자체)
  vendor_name text,                       -- 외주업체명 (외주일 경우)
  priority text not null default '보통'
    check (priority in ('긴급', '높음', '보통', '낮음')),
  reported_by text,                       -- 등록한 직원 이름
  assigned_to text,                       -- 처리 담당자
  reported_at timestamptz not null default now(),
  resolved_at timestamptz,                -- 완료 처리된 시각
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_defects_room on defects(room_id);
create index if not exists idx_defects_category on defects(category_id);
create index if not exists idx_defects_status on defects(status);

-- 4) 하자 사진 테이블
-- 하자 한 건에 여러 장의 사진을 첨부할 수 있도록 별도 테이블로 분리
create table if not exists defect_photos (
  id bigint generated always as identity primary key,
  defect_id bigint not null references defects(id) on delete cascade,
  photo_url text not null,                -- Supabase Storage에 올린 이미지 URL
  uploaded_at timestamptz not null default now()
);

-- 5) 하자 상태 변경 이력 테이블
-- "언제 누가 무슨 상태로 바꿨는지" 추적용. 추후 보고서/감사용으로 유용.
create table if not exists defect_status_history (
  id bigint generated always as identity primary key,
  defect_id bigint not null references defects(id) on delete cascade,
  old_status text,
  new_status text not null,
  changed_by text,
  note text,
  changed_at timestamptz not null default now()
);

-- updated_at 자동 갱신 트리거
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_defects_updated_at on defects;
create trigger trg_defects_updated_at
  before update on defects
  for each row execute function set_updated_at();

-- 상태 변경 시 자동으로 이력 테이블에 기록하는 트리거
create or replace function log_defect_status_change()
returns trigger as $$
begin
  if (old.status is distinct from new.status) then
    insert into defect_status_history (defect_id, old_status, new_status, changed_by)
    values (new.id, old.status, new.status, new.assigned_to);
    if new.status = '완료' and old.status is distinct from '완료' then
      new.resolved_at = now();
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_defect_status_log on defects;
create trigger trg_defect_status_log
  before update on defects
  for each row execute function log_defect_status_change();

-- ============================================================
-- 6) Row Level Security (RLS) 설정
-- 초보자를 위한 가장 단순한 설정: 로그인 없이 누구나(anon key로)
-- 읽고 쓸 수 있게 합니다. 지점 직원만 쓰는 내부 도구이므로
-- 우선 단순하게 시작하고, 추후 필요시 로그인 기능을 추가해 강화할 수 있습니다.
-- ============================================================

alter table rooms enable row level security;
alter table defect_categories enable row level security;
alter table defects enable row level security;
alter table defect_photos enable row level security;
alter table defect_status_history enable row level security;

create policy "anon_select_rooms" on rooms for select using (true);
create policy "anon_insert_rooms" on rooms for insert with check (true);
create policy "anon_update_rooms" on rooms for update using (true);

create policy "anon_select_categories" on defect_categories for select using (true);

create policy "anon_select_defects" on defects for select using (true);
create policy "anon_insert_defects" on defects for insert with check (true);
create policy "anon_update_defects" on defects for update using (true);
create policy "anon_delete_defects" on defects for delete using (true);

create policy "anon_select_photos" on defect_photos for select using (true);
create policy "anon_insert_photos" on defect_photos for insert with check (true);
create policy "anon_delete_photos" on defect_photos for delete using (true);

create policy "anon_select_history" on defect_status_history for select using (true);
create policy "anon_insert_history" on defect_status_history for insert with check (true);

-- ============================================================
-- 7) 샘플 객실 데이터 (선택 사항)
-- 실제 운영 객실 목록으로 교체하거나, 사이트 화면에서 직접 추가해도 됩니다.
-- 아래는 예시이므로 지점 실제 객실번호로 바꿔서 사용하세요.
-- ============================================================
-- insert into rooms (room_number, floor, room_type) values
--   ('702', '7F', '스튜디오 로프트'),
--   ('705', '7F', '스튜디오 로프트'),
--   ('709', '7F', '패밀리 투룸 오션');

-- ============================================================
-- 끝. 이 위까지 전체를 복사해서 Supabase SQL Editor에서 실행하세요.
-- ============================================================
