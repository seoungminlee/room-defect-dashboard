-- ============================================================
-- 객실 하자관리 시스템 - v9 스키마 (관리자 비밀번호 초기화 함수)
-- 작성일: 2026-06-23
-- 실행 전 v8 스키마가 적용되어 있어야 합니다.
--
-- 배경:
--   Supabase에서 다른 사용자의 비밀번호를 바꾸려면 원래 service_role key가
--   필요합니다. 그런데 service_role key는 소스에 넣으면 안 됩니다.
--   대신 security definer 함수를 만들면 — 함수 내부는 DB 슈퍼유저 권한으로
--   auth.users를 직접 수정할 수 있어서 anon key만으로도 안전하게 처리됩니다.
--   단, 함수 자체는 "호출자가 admin인지" 체크하므로 staff는 사용 불가합니다.
-- ============================================================

create or replace function admin_reset_user_password(
  target_email text,
  new_password text
)
returns void as $$
declare
  v_caller_role text;
  v_target_uid  uuid;
begin
  -- 1) 호출자가 admin인지 확인
  v_caller_role := coalesce(auth.jwt() -> 'user_metadata' ->> 'role', 'staff');
  if v_caller_role <> 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  -- 2) 대상 이메일로 uid 조회
  select id into v_target_uid from auth.users where email = target_email;
  if v_target_uid is null then
    raise exception 'User not found: %', target_email;
  end if;

  -- 3) 비밀번호 업데이트 (auth.users 직접 수정)
  update auth.users
  set
    encrypted_password = crypt(new_password, gen_salt('bf')),
    updated_at = now()
  where id = v_target_uid;
end;
$$ language plpgsql security definer;

-- 함수 실행 권한: 인증된 사용자만 호출 가능 (내부에서 role 재확인)
revoke all on function admin_reset_user_password(text, text) from public;
grant execute on function admin_reset_user_password(text, text) to authenticated;

-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
-- ============================================================
