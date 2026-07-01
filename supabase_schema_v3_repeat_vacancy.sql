-- ============================================================
-- 객실 하자관리 시스템 - v3 추가 스키마 (반복하자 / 방막 관리)
-- 작성일: 2026-06-23
-- 설명: 기존 v1, v2 스키마는 그대로 두고 이 파일만 추가로 실행하세요.
--       기존 데이터는 건드리지 않고 새 컬럼/트리거만 추가합니다.
--
-- 배경: 향후 RAM 분석(MTBF/MTTR/가용률) 화면을 만들 때 필요한
--       원재료 데이터(방막 기간, 반복 여부)를 지금부터 빠짐없이
--       쌓아두기 위한 작업입니다. 화면은 데이터가 쌓인 뒤 별도로 만듭니다.
-- ============================================================

-- ------------------------------------------------------------
-- 1) defects 테이블에 방막 / 반복하자 컬럼 추가
-- ------------------------------------------------------------
alter table defects add column if not exists is_vacant boolean not null default false;       -- 방막여부 (Y/N)
alter table defects add column if not exists vacant_days numeric(6,1) not null default 0;     -- 방막기간(일)
alter table defects add column if not exists is_repeated boolean not null default false;      -- 반복하자 여부 (자동 판별)

create index if not exists idx_defects_room_location on defects(room_id, location_id);

-- ------------------------------------------------------------
-- 2) 반복하자 자동 판별 트리거
-- 기준: 같은 객실 + 같은 공종(category_id) + (있으면) 같은 부위(location_id)로
--       최근 30일 이내에 이미 등록된 하자가 있으면 "반복하자"로 표시합니다.
--       기준 일수는 아래 REPEAT_WINDOW_DAYS 값만 바꾸면 조정됩니다.
-- ------------------------------------------------------------
create or replace function mark_repeated_defect()
returns trigger as $$
declare
  repeat_window_days int := 30;
  prior_count int;
begin
  select count(*) into prior_count
  from defects
  where room_id = new.room_id
    and category_id = new.category_id
    and (new.location_id is null or location_id = new.location_id)
    and id <> new.id
    and created_at >= (new.created_at - (repeat_window_days || ' days')::interval)
    and created_at < new.created_at;

  if prior_count > 0 then
    new.is_repeated := true;
  end if;

  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_mark_repeated_defect on defects;
create trigger trg_mark_repeated_defect
  before insert on defects
  for each row execute function mark_repeated_defect();

-- 참고: 이 트리거는 INSERT 시점에만 동작합니다. 과거 데이터를 일괄 재판별하려면
-- 아래 UPDATE 문을 한 번 실행해 기존 데이터에도 반복하자 여부를 채울 수 있습니다.
-- (한 번만 실행하면 됩니다. 여러 번 실행해도 안전합니다.)
update defects d
set is_repeated = true
where exists (
  select 1 from defects d2
  where d2.room_id = d.room_id
    and d2.category_id = d.category_id
    and (d.location_id is null or d2.location_id = d.location_id)
    and d2.id <> d.id
    and d2.created_at >= (d.created_at - interval '30 days')
    and d2.created_at < d.created_at
);

-- ============================================================
-- 끝. 여기까지 SQL Editor에 붙여넣고 Run 누르세요.
-- ============================================================
