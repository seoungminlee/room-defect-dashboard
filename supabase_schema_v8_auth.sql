-- ============================================================
-- 객실 하자관리 시스템 - v8 스키마 (Auth 기반 권한 분리)
-- 작성일: 2026-06-23
-- 실행 전 반드시 v1~v7 스키마가 모두 적용되어 있어야 합니다.
--
-- 변경 내용:
--   1) 기존 anon 전체허용 RLS 정책 → auth.uid() 기반으로 전면 교체
--      - 로그인하지 않으면 어떤 데이터도 접근 불가
--      - admin/staff 공통 테이블은 인증된 사용자 전원 허용
--      - admin 전용 테이블은 user_metadata.role = 'admin' 체크
--   2) defect_audit_log 테이블 신설
--      - 하자 등록/수정/삭제 이력을 자동으로 기록
--      - admin만 조회 가능
--   3) 트리거: defects 변경 시 audit_log 자동 적재
-- ============================================================

-- ============================================================
-- 헬퍼 함수: 현재 로그인 사용자의 role 반환
-- user_metadata.role 값(admin / staff)을 읽어옵니다.
-- ============================================================
create or replace function get_my_role()
returns text as $$
  select coalesce(
    (auth.jwt() -> 'user_metadata' ->> 'role'),
    'staff'
  );
$$ language sql stable security definer;


-- ============================================================
-- 1) 기존 anon RLS 정책 제거 후 auth 기반으로 교체
--    (각 테이블별로 anon 정책 drop → auth 정책 create)
-- ============================================================

------------------------------------------------------------
-- rooms
------------------------------------------------------------
drop policy if exists "anon_select_rooms"  on rooms;
drop policy if exists "anon_insert_rooms"  on rooms;
drop policy if exists "anon_update_rooms"  on rooms;
drop policy if exists "anon_delete_rooms"  on rooms;

create policy "auth_select_rooms" on rooms for select using (auth.role() = 'authenticated');
create policy "auth_insert_rooms" on rooms for insert with check (auth.role() = 'authenticated');
create policy "auth_update_rooms" on rooms for update using (auth.role() = 'authenticated');
create policy "auth_delete_rooms" on rooms for delete using (get_my_role() = 'admin');

------------------------------------------------------------
-- room_types
------------------------------------------------------------
drop policy if exists "anon_select_room_types" on room_types;
drop policy if exists "anon_insert_room_types" on room_types;
drop policy if exists "anon_update_room_types" on room_types;
drop policy if exists "anon_delete_room_types" on room_types;

create policy "auth_select_room_types" on room_types for select using (auth.role() = 'authenticated');
create policy "auth_insert_room_types" on room_types for insert with check (get_my_role() = 'admin');
create policy "auth_update_room_types" on room_types for update using (get_my_role() = 'admin');
create policy "auth_delete_room_types" on room_types for delete using (get_my_role() = 'admin');

------------------------------------------------------------
-- defect_categories
------------------------------------------------------------
drop policy if exists "anon_select_categories" on defect_categories;
drop policy if exists "anon_insert_categories" on defect_categories;
drop policy if exists "anon_update_categories" on defect_categories;
drop policy if exists "anon_delete_categories" on defect_categories;

create policy "auth_select_categories" on defect_categories for select using (auth.role() = 'authenticated');
create policy "auth_insert_categories" on defect_categories for insert with check (get_my_role() = 'admin');
create policy "auth_update_categories" on defect_categories for update using (get_my_role() = 'admin');
create policy "auth_delete_categories" on defect_categories for delete using (get_my_role() = 'admin');

------------------------------------------------------------
-- defect_locations
------------------------------------------------------------
drop policy if exists "anon_select_locations" on defect_locations;
drop policy if exists "anon_insert_locations" on defect_locations;
drop policy if exists "anon_update_locations" on defect_locations;
drop policy if exists "anon_delete_locations" on defect_locations;

create policy "auth_select_locations" on defect_locations for select using (auth.role() = 'authenticated');
create policy "auth_insert_locations" on defect_locations for insert with check (get_my_role() = 'admin');
create policy "auth_update_locations" on defect_locations for update using (get_my_role() = 'admin');
create policy "auth_delete_locations" on defect_locations for delete using (get_my_role() = 'admin');

------------------------------------------------------------
-- defect_parts
------------------------------------------------------------
drop policy if exists "anon_select_parts" on defect_parts;
drop policy if exists "anon_insert_parts" on defect_parts;
drop policy if exists "anon_update_parts" on defect_parts;
drop policy if exists "anon_delete_parts" on defect_parts;

create policy "auth_select_parts" on defect_parts for select using (auth.role() = 'authenticated');
create policy "auth_insert_parts" on defect_parts for insert with check (get_my_role() = 'admin');
create policy "auth_update_parts" on defect_parts for update using (get_my_role() = 'admin');
create policy "auth_delete_parts" on defect_parts for delete using (get_my_role() = 'admin');

------------------------------------------------------------
-- defects  (등록·수정은 staff 포함 모두, 삭제는 admin만)
------------------------------------------------------------
drop policy if exists "anon_select_defects" on defects;
drop policy if exists "anon_insert_defects" on defects;
drop policy if exists "anon_update_defects" on defects;
drop policy if exists "anon_delete_defects" on defects;

create policy "auth_select_defects" on defects for select using (auth.role() = 'authenticated');
create policy "auth_insert_defects" on defects for insert with check (auth.role() = 'authenticated');
create policy "auth_update_defects" on defects for update using (auth.role() = 'authenticated');
create policy "auth_delete_defects" on defects for delete using (get_my_role() = 'admin');

------------------------------------------------------------
-- defect_parts_used
------------------------------------------------------------
drop policy if exists "anon_select_parts_used" on defect_parts_used;
drop policy if exists "anon_insert_parts_used" on defect_parts_used;
drop policy if exists "anon_update_parts_used" on defect_parts_used;
drop policy if exists "anon_delete_parts_used" on defect_parts_used;

create policy "auth_select_parts_used" on defect_parts_used for select using (auth.role() = 'authenticated');
create policy "auth_insert_parts_used" on defect_parts_used for insert with check (auth.role() = 'authenticated');
create policy "auth_update_parts_used" on defect_parts_used for update using (auth.role() = 'authenticated');
create policy "auth_delete_parts_used" on defect_parts_used for delete using (auth.role() = 'authenticated');

------------------------------------------------------------
-- defect_photos
------------------------------------------------------------
drop policy if exists "anon_select_photos" on defect_photos;
drop policy if exists "anon_insert_photos" on defect_photos;
drop policy if exists "anon_delete_photos" on defect_photos;

create policy "auth_select_photos" on defect_photos for select using (auth.role() = 'authenticated');
create policy "auth_insert_photos" on defect_photos for insert with check (auth.role() = 'authenticated');
create policy "auth_delete_photos" on defect_photos for delete using (auth.role() = 'authenticated');

------------------------------------------------------------
-- defect_status_history
------------------------------------------------------------
drop policy if exists "anon_select_status_history" on defect_status_history;
drop policy if exists "anon_insert_status_history" on defect_status_history;

create policy "auth_select_status_history" on defect_status_history for select using (auth.role() = 'authenticated');
create policy "auth_insert_status_history" on defect_status_history for insert with check (auth.role() = 'authenticated');

------------------------------------------------------------
-- part_stock_in / out / adjustments
------------------------------------------------------------
drop policy if exists "anon_select_stock_in"    on part_stock_in;
drop policy if exists "anon_insert_stock_in"    on part_stock_in;
drop policy if exists "anon_delete_stock_in"    on part_stock_in;
drop policy if exists "anon_select_stock_out"   on part_stock_out;
drop policy if exists "anon_insert_stock_out"   on part_stock_out;
drop policy if exists "anon_delete_stock_out"   on part_stock_out;
drop policy if exists "anon_select_adjustments" on part_stock_adjustments;
drop policy if exists "anon_insert_adjustments" on part_stock_adjustments;

create policy "auth_select_stock_in"    on part_stock_in    for select using (auth.role() = 'authenticated');
create policy "auth_insert_stock_in"    on part_stock_in    for insert with check (auth.role() = 'authenticated');
create policy "auth_delete_stock_in"    on part_stock_in    for delete using (get_my_role() = 'admin');
create policy "auth_select_stock_out"   on part_stock_out   for select using (auth.role() = 'authenticated');
create policy "auth_insert_stock_out"   on part_stock_out   for insert with check (auth.role() = 'authenticated');
create policy "auth_delete_stock_out"   on part_stock_out   for delete using (get_my_role() = 'admin');
create policy "auth_select_adjustments" on part_stock_adjustments for select using (auth.role() = 'authenticated');
create policy "auth_insert_adjustments" on part_stock_adjustments for insert with check (auth.role() = 'authenticated');

------------------------------------------------------------
-- system_settings  (조회는 전원, 수정은 admin만)
------------------------------------------------------------
drop policy if exists "anon_select_settings" on system_settings;
drop policy if exists "anon_update_settings" on system_settings;

create policy "auth_select_settings" on system_settings for select using (auth.role() = 'authenticated');
create policy "auth_update_settings" on system_settings for update using (get_my_role() = 'admin');

------------------------------------------------------------
-- employees  (조회는 전원, 추가·수정·삭제는 admin만)
------------------------------------------------------------
drop policy if exists "anon_select_employees" on employees;
drop policy if exists "anon_insert_employees" on employees;
drop policy if exists "anon_update_employees" on employees;
drop policy if exists "anon_delete_employees" on employees;

create policy "auth_select_employees" on employees for select using (auth.role() = 'authenticated');
create policy "auth_insert_employees" on employees for insert with check (get_my_role() = 'admin');
create policy "auth_update_employees" on employees for update using (get_my_role() = 'admin');
create policy "auth_delete_employees" on employees for delete using (get_my_role() = 'admin');


-- ============================================================
-- 2) defect_audit_log 테이블 신설 (admin 전용 열람)
-- ============================================================
create table if not exists defect_audit_log (
  id            bigint generated always as identity primary key,
  defect_id     bigint,                        -- 대상 하자 ID (삭제 시 null 가능)
  action        text not null,                 -- 'INSERT' | 'UPDATE' | 'DELETE'
  changed_by    uuid references auth.users(id), -- 변경한 사용자 (auth.uid())
  changed_by_email text,                       -- 이메일 (조회 편의용, 트리거에서 채움)
  before_data   jsonb,                         -- 변경 전 row (UPDATE/DELETE)
  after_data    jsonb,                         -- 변경 후 row (INSERT/UPDATE)
  changed_at    timestamptz not null default now()
);

alter table defect_audit_log enable row level security;

-- admin만 조회 가능, 누구도 직접 insert/update/delete 불가 (트리거만 적재)
create policy "admin_select_audit_log" on defect_audit_log
  for select using (get_my_role() = 'admin');


-- ============================================================
-- 3) 트리거: defects 변경 시 audit_log 자동 적재
-- ============================================================
create or replace function log_defect_change()
returns trigger as $$
declare
  v_email text;
begin
  -- auth.users에서 이메일 조회 (security definer로 접근 가능)
  select email into v_email from auth.users where id = auth.uid();

  if (tg_op = 'INSERT') then
    insert into defect_audit_log (defect_id, action, changed_by, changed_by_email, before_data, after_data)
    values (new.id, 'INSERT', auth.uid(), v_email, null, to_jsonb(new));

  elsif (tg_op = 'UPDATE') then
    insert into defect_audit_log (defect_id, action, changed_by, changed_by_email, before_data, after_data)
    values (new.id, 'UPDATE', auth.uid(), v_email, to_jsonb(old), to_jsonb(new));

  elsif (tg_op = 'DELETE') then
    insert into defect_audit_log (defect_id, action, changed_by, changed_by_email, before_data, after_data)
    values (old.id, 'DELETE', auth.uid(), v_email, to_jsonb(old), null);
  end if;

  return coalesce(new, old);
end;
$$ language plpgsql security definer;

drop trigger if exists trg_log_defect_change on defects;
create trigger trg_log_defect_change
  after insert or update or delete on defects
  for each row execute function log_defect_change();


-- ============================================================
-- 실행 후 Supabase 대시보드에서 해야 할 작업
-- ============================================================
-- 1) Authentication → Users → "Invite user"로 계정 생성
--    (이메일 초대 방식, 비밀번호는 초대 수락 시 본인이 설정)
--
-- 2) 계정 생성 후 각 사용자의 user_metadata에 role 설정:
--    Authentication → Users → 해당 유저 클릭 → Edit → Raw user meta data:
--    {
--      "role": "admin"    ← 마스터 계정 1개
--    }
--    {
--      "role": "staff"    ← 일반 계정 8개 (기본값이므로 생략 가능)
--    }
--
-- 3) 앱에서 로그인 후 정상 동작 확인
-- ============================================================
