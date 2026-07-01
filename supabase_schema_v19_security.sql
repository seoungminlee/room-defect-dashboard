-- ============================================================
-- 객실 하자관리 시스템 - v19 보안 강화 마이그레이션
-- 작성일: 2026-07-02
-- 실행 전 v18까지 적용되어 있어야 합니다.
--
-- 이 스크립트가 해결하는 취약점:
--   [C-1] 권한 상승: role이 user_metadata에 저장되어 있어
--         모든 사용자가 스스로 admin으로 변경 가능했음
--         → role을 app_metadata(관리자만 수정 가능)로 이전
--   [H-1] viewer의 쓰기 권한이 DB에서 차단되지 않았음
--         → 전 테이블 RLS 정책을 role 기반으로 전면 재구성
--   [C-2] reset_operation_data()에 admin 검증 추가 (하단 7번 참조)
--
-- ★ 실행 후 필수: 모든 사용자는 로그아웃 후 재로그인해야 합니다.
--   (기존 JWT 토큰에는 app_metadata.role이 없어 최대 1시간 동안
--    쓰기 권한이 viewer 수준으로 제한될 수 있음)
-- ============================================================


-- ============================================================
-- 1) role을 user_metadata → app_metadata로 이전
--    app_metadata는 service_role만 수정 가능 (사용자 본인 수정 불가)
-- ============================================================
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
      || jsonb_build_object('role', coalesce(raw_user_meta_data ->> 'role', 'staff'))
where coalesce(raw_app_meta_data ->> 'role', '') = '';

-- user_metadata에서 role 제거 (혼동 방지 — 이후 app_metadata가 유일한 출처)
update auth.users
set raw_user_meta_data = raw_user_meta_data - 'role'
where raw_user_meta_data ? 'role';


-- ============================================================
-- 2) 헬퍼 함수 교체
--    get_my_role(): app_metadata 기반. 값이 없으면 'viewer'(최소 권한)
--    can_edit(): admin 또는 staff인지 (쓰기 권한 공통 체크)
-- ============================================================
create or replace function get_my_role()
returns text as $$
  select coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role'),
    'viewer'
  );
$$ language sql stable security definer;

create or replace function can_edit()
returns boolean as $$
  select get_my_role() in ('admin', 'staff');
$$ language sql stable security definer;


-- ============================================================
-- 3) 관리자 함수 교체 (app_metadata 기준으로 검증·수정)
-- ============================================================

-- 3-1) 사용자 목록 조회
create or replace function admin_list_users()
returns table (
  id            uuid,
  email         text,
  role          text,
  last_sign_in  timestamptz,
  created_at    timestamptz
) as $$
begin
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role', 'viewer') <> 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  return query
  select
    u.id,
    u.email::text,
    coalesce(u.raw_app_meta_data ->> 'role', 'viewer') as role,
    u.last_sign_in_at,
    u.created_at
  from auth.users u
  order by u.created_at;
end;
$$ language plpgsql security definer;

revoke all on function admin_list_users() from public;
grant execute on function admin_list_users() to authenticated;

-- 3-2) 사용자 role 변경 (viewer 지원 추가)
create or replace function admin_set_user_role(
  target_email text,
  new_role     text   -- 'admin' | 'staff' | 'viewer'
)
returns void as $$
declare
  v_target_uid uuid;
begin
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role', 'viewer') <> 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  if new_role not in ('admin', 'staff', 'viewer') then
    raise exception 'Invalid role: must be admin, staff or viewer';
  end if;

  select u.id into v_target_uid from auth.users u where u.email = target_email;
  if v_target_uid is null then
    raise exception 'User not found: %', target_email;
  end if;

  -- 자기 자신의 admin 해제 방지 (관리자 0명 사고 예방)
  if v_target_uid = auth.uid() and new_role <> 'admin' then
    raise exception '자기 자신의 관리자 권한은 해제할 수 없습니다.';
  end if;

  update auth.users
  set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
        || jsonb_build_object('role', new_role),
      updated_at = now()
  where id = v_target_uid;
end;
$$ language plpgsql security definer;

revoke all on function admin_set_user_role(text, text) from public;
grant execute on function admin_set_user_role(text, text) to authenticated;

-- 3-3) 비밀번호 초기화 (v9 함수의 검증 기준 교체)
create or replace function admin_reset_user_password(
  target_email text,
  new_password text
)
returns void as $$
declare
  v_target_uid uuid;
begin
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role', 'viewer') <> 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  if length(new_password) < 8 then
    raise exception '비밀번호는 8자 이상이어야 합니다.';
  end if;

  select u.id into v_target_uid from auth.users u where u.email = target_email;
  if v_target_uid is null then
    raise exception 'User not found: %', target_email;
  end if;

  update auth.users
  set encrypted_password = crypt(new_password, gen_salt('bf')),
      updated_at = now()
  where id = v_target_uid;
end;
$$ language plpgsql security definer;

revoke all on function admin_reset_user_password(text, text) from public;
grant execute on function admin_reset_user_password(text, text) to authenticated;


-- ============================================================
-- 4) 전 테이블 RLS 정책 전면 재구성
--    기존 정책 전부 제거 후 role 기반으로 재생성
--    (viewer = 조회만 / staff = 운영 데이터 쓰기 / admin = 전체)
-- ============================================================
do $$
declare
  p record;
begin
  for p in
    select policyname, tablename
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'rooms','room_types','defect_categories','defect_locations','defect_parts',
        'defects','defect_parts_used','defect_photos','defect_status_history',
        'part_stock_in','part_stock_out','part_stock_adjustments','system_settings',
        'employees','announcements','vendors','pm_schedules','pm_logs',
        'monthly_budget','notification_rules','defect_status_logs','defect_comments',
        'app_settings','update_logs'
      )
  loop
    execute format('drop policy if exists %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;

-- ── 조회: 로그인 사용자 전원 (모든 테이블 공통) ──────────────
create policy "sel_rooms"           on rooms                  for select using (auth.uid() is not null);
create policy "sel_room_types"      on room_types             for select using (auth.uid() is not null);
create policy "sel_categories"      on defect_categories      for select using (auth.uid() is not null);
create policy "sel_locations"       on defect_locations       for select using (auth.uid() is not null);
create policy "sel_parts"           on defect_parts           for select using (auth.uid() is not null);
create policy "sel_defects"         on defects                for select using (auth.uid() is not null);
create policy "sel_parts_used"      on defect_parts_used      for select using (auth.uid() is not null);
create policy "sel_photos"          on defect_photos          for select using (auth.uid() is not null);
create policy "sel_status_history"  on defect_status_history  for select using (auth.uid() is not null);
create policy "sel_stock_in"        on part_stock_in          for select using (auth.uid() is not null);
create policy "sel_stock_out"       on part_stock_out         for select using (auth.uid() is not null);
create policy "sel_adjustments"     on part_stock_adjustments for select using (auth.uid() is not null);
create policy "sel_settings"        on system_settings        for select using (auth.uid() is not null);
create policy "sel_employees"       on employees              for select using (auth.uid() is not null);
create policy "sel_announcements"   on announcements          for select using (auth.uid() is not null);
create policy "sel_vendors"         on vendors                for select using (auth.uid() is not null);
create policy "sel_pm_schedules"    on pm_schedules           for select using (auth.uid() is not null);
create policy "sel_pm_logs"         on pm_logs                for select using (auth.uid() is not null);
create policy "sel_budget"          on monthly_budget         for select using (auth.uid() is not null);
create policy "sel_notif_rules"     on notification_rules     for select using (auth.uid() is not null);
create policy "sel_status_logs"     on defect_status_logs     for select using (auth.uid() is not null);
create policy "sel_comments"        on defect_comments        for select using (auth.uid() is not null);
create policy "sel_app_settings"    on app_settings           for select using (auth.uid() is not null);
create policy "sel_update_logs"     on update_logs            for select using (auth.uid() is not null);

-- ── 운영 데이터: staff·admin 쓰기 가능 ───────────────────────
create policy "ins_rooms"          on rooms for insert with check (can_edit());
create policy "upd_rooms"          on rooms for update using (can_edit());
create policy "del_rooms"          on rooms for delete using (get_my_role() = 'admin');

create policy "ins_defects"        on defects for insert with check (can_edit());
create policy "upd_defects"        on defects for update using (can_edit());
create policy "del_defects"        on defects for delete using (get_my_role() = 'admin');

create policy "ins_parts_used"     on defect_parts_used for insert with check (can_edit());
create policy "upd_parts_used"     on defect_parts_used for update using (can_edit());
create policy "del_parts_used"     on defect_parts_used for delete using (can_edit());

create policy "ins_photos"         on defect_photos for insert with check (can_edit());
create policy "del_photos"         on defect_photos for delete using (can_edit());

create policy "ins_status_history" on defect_status_history for insert with check (can_edit());
create policy "ins_status_logs"    on defect_status_logs    for insert with check (can_edit());

create policy "ins_comments"       on defect_comments for insert with check (can_edit());
create policy "del_comments"       on defect_comments for delete
  using (auth.uid() = author_id or get_my_role() = 'admin');

create policy "ins_stock_in"       on part_stock_in for insert with check (can_edit());
create policy "del_stock_in"       on part_stock_in for delete using (get_my_role() = 'admin');
create policy "ins_stock_out"      on part_stock_out for insert with check (can_edit());
create policy "del_stock_out"      on part_stock_out for delete using (get_my_role() = 'admin');
create policy "ins_adjustments"    on part_stock_adjustments for insert with check (can_edit());

create policy "ins_pm_logs"        on pm_logs for insert with check (can_edit());
create policy "upd_pm_logs"        on pm_logs for update using (can_edit());
create policy "del_pm_logs"        on pm_logs for delete using (get_my_role() = 'admin');

create policy "upd_pm_schedules"   on pm_schedules for update using (can_edit());

-- 공지: staff·admin 작성 가능, 중요공지는 admin만 (v18 규칙 유지)
create policy "ins_announcements"  on announcements for insert
  with check (can_edit() and (is_important = false or get_my_role() = 'admin'));
create policy "upd_announcements"  on announcements for update
  using (created_by = auth.uid() or get_my_role() = 'admin')
  with check (is_important = false or get_my_role() = 'admin');
create policy "del_announcements"  on announcements for delete
  using (created_by = auth.uid() or get_my_role() = 'admin');

-- ── 마스터 데이터·설정: admin만 쓰기 ─────────────────────────
create policy "ins_room_types"   on room_types for insert with check (get_my_role() = 'admin');
create policy "upd_room_types"   on room_types for update using (get_my_role() = 'admin');
create policy "del_room_types"   on room_types for delete using (get_my_role() = 'admin');

create policy "ins_categories"   on defect_categories for insert with check (get_my_role() = 'admin');
create policy "upd_categories"   on defect_categories for update using (get_my_role() = 'admin');
create policy "del_categories"   on defect_categories for delete using (get_my_role() = 'admin');

create policy "ins_locations"    on defect_locations for insert with check (get_my_role() = 'admin');
create policy "upd_locations"    on defect_locations for update using (get_my_role() = 'admin');
create policy "del_locations"    on defect_locations for delete using (get_my_role() = 'admin');

create policy "ins_parts"        on defect_parts for insert with check (get_my_role() = 'admin');
create policy "upd_parts"        on defect_parts for update using (get_my_role() = 'admin');
create policy "del_parts"        on defect_parts for delete using (get_my_role() = 'admin');

create policy "ins_employees"    on employees for insert with check (get_my_role() = 'admin');
create policy "upd_employees"    on employees for update using (get_my_role() = 'admin');
create policy "del_employees"    on employees for delete using (get_my_role() = 'admin');

create policy "ins_vendors"      on vendors for insert with check (get_my_role() = 'admin');
create policy "upd_vendors"      on vendors for update using (get_my_role() = 'admin');
create policy "del_vendors"      on vendors for delete using (get_my_role() = 'admin');

create policy "ins_pm_schedules" on pm_schedules for insert with check (get_my_role() = 'admin');
create policy "del_pm_schedules" on pm_schedules for delete using (get_my_role() = 'admin');

create policy "ins_budget"       on monthly_budget for insert with check (get_my_role() = 'admin');
create policy "upd_budget"       on monthly_budget for update using (get_my_role() = 'admin');
create policy "del_budget"       on monthly_budget for delete using (get_my_role() = 'admin');

create policy "ins_notif_rules"  on notification_rules for insert with check (get_my_role() = 'admin');
create policy "upd_notif_rules"  on notification_rules for update using (get_my_role() = 'admin');
create policy "del_notif_rules"  on notification_rules for delete using (get_my_role() = 'admin');

create policy "upd_settings"     on system_settings for update using (get_my_role() = 'admin');

create policy "ins_app_settings" on app_settings for insert with check (get_my_role() = 'admin');
create policy "upd_app_settings" on app_settings for update using (get_my_role() = 'admin');

create policy "ins_update_logs"  on update_logs for insert with check (get_my_role() = 'admin');
create policy "upd_update_logs"  on update_logs for update using (get_my_role() = 'admin');
create policy "del_update_logs"  on update_logs for delete using (get_my_role() = 'admin');


-- ============================================================
-- 5) (확인용) 현재 reset_operation_data 정의 조회
--    아래 6번 실행 전에 이 쿼리로 기존 TRUNCATE 대상을 확인하세요.
--    목록이 6번과 다르면 6번의 truncate 목록을 맞춰서 수정 후 실행.
-- ============================================================
-- select prosrc from pg_proc where proname = 'reset_operation_data';


-- ============================================================
-- 6) reset_operation_data 교체 — admin 검증 추가
--    TRUNCATE 대상은 기존 운영 중인 함수 정의와 동일하게 유지
--    (2026-07-02 기존 정의 대조 완료 — 변경점은 admin 검증뿐)
-- ============================================================
create or replace function reset_operation_data()
returns void as $$
begin
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role', 'viewer') <> 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  truncate table
    defect_status_logs,
    defect_comments,
    defect_parts_used,
    defect_photos,
    part_stock_adjustments,
    part_stock_in,
    part_stock_out,
    defects,
    announcements
    restart identity cascade;

  -- 재고 수량 초기화 (입출고 이력이 사라졌으므로)
  update defect_parts set current_stock = 0 where id is not null;
end;
$$ language plpgsql security definer;

revoke all on function reset_operation_data() from public;
grant execute on function reset_operation_data() to authenticated;


-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 실행 후 체크리스트:
--   1. 모든 사용자 재로그인 안내
--   2. Edge Function 재배포 (invite-user, delete-user — v19 대응 버전)
--   3. staff 계정으로 하자 등록 정상 동작 확인
--   4. viewer 계정으로 하자 등록 시도 → 거부되는지 확인 (RLS 에러)
--   5. 브라우저 콘솔에서 아래 실행해도 admin이 되지 않는지 확인:
--      sb.auth.updateUser({data:{role:'admin'}})
--      → user_metadata만 바뀌고 권한은 그대로여야 정상
-- ============================================================
