-- ============================================================
-- 객실 하자관리 시스템 - v23 비밀번호 정책 일치화
-- 작성일: 2026-07-02
--
-- 배경:
--   Supabase Auth 정책을 10자 이상 + 영문·숫자로 상향했으나,
--   관리자 비밀번호 초기화 함수(admin_reset_user_password)는
--   auth.users를 직접 수정하므로 Auth 정책을 우회함.
--   → 함수 내부 검증을 동일 정책으로 상향.
-- ============================================================

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

  -- 비밀번호 정책: 8자 이상, 영문+숫자 포함 (Auth 설정과 동일)
  if length(new_password) < 8
     or new_password !~ '[A-Za-z]'
     or new_password !~ '[0-9]' then
    raise exception '비밀번호는 8자 이상, 영문과 숫자를 모두 포함해야 합니다.';
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

-- 끝. SQL Editor에 붙여넣고 Run 하세요.
