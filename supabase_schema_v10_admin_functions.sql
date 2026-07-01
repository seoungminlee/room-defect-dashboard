-- ============================================================
-- 객실 하자관리 시스템 - v10 스키마 (관리자 전용 함수)
-- 작성일: 2026-06-23
-- 실행 전 v9 스키마가 적용되어 있어야 합니다.
--
-- 포함 내용:
--   1) admin_list_users()      — 전체 사용자 목록 조회 (admin 전용)
--   2) admin_set_user_role()   — 사용자 role 변경 (admin 전용)
-- ============================================================

-- ============================================================
-- 1) 사용자 목록 조회
--    auth.users는 일반 쿼리로 접근 불가 → security definer 함수로 우회
-- ============================================================
create or replace function admin_list_users()
returns table (
  id            uuid,
  email         text,
  role          text,
  last_sign_in  timestamptz,
  created_at    timestamptz
) as $$
begin
  -- admin만 호출 가능
  if coalesce(auth.jwt() -> 'user_metadata' ->> 'role', 'staff') <> 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  return query
  select
    u.id,
    u.email,
    coalesce(u.raw_user_meta_data ->> 'role', 'staff') as role,
    u.last_sign_in_at,
    u.created_at
  from auth.users u
  order by u.created_at;
end;
$$ language plpgsql security definer;

revoke all on function admin_list_users() from public;
grant execute on function admin_list_users() to authenticated;


-- ============================================================
-- 2) 사용자 role 변경
-- ============================================================
create or replace function admin_set_user_role(
  target_email text,
  new_role     text   -- 'admin' | 'staff'
)
returns void as $$
declare
  v_target_uid uuid;
begin
  if coalesce(auth.jwt() -> 'user_metadata' ->> 'role', 'staff') <> 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  if new_role not in ('admin', 'staff') then
    raise exception 'Invalid role: must be admin or staff';
  end if;

  select id into v_target_uid from auth.users where email = target_email;
  if v_target_uid is null then
    raise exception 'User not found: %', target_email;
  end if;

  update auth.users
  set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('role', new_role),
      updated_at = now()
  where id = v_target_uid;
end;
$$ language plpgsql security definer;

revoke all on function admin_set_user_role(text, text) from public;
grant execute on function admin_set_user_role(text, text) to authenticated;

-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
-- ============================================================
