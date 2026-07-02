-- ============================================================
-- 객실 하자관리 시스템 - v24 초기화 계정 비밀번호 강제 변경
-- 작성일: 2026-07-02
-- 실행 전 v23까지 적용되어 있어야 합니다.
--
-- 내용:
--   관리자가 임시 비밀번호로 초기화한 계정에 must_change_pw 플래그를
--   기록 → 해당 사용자가 다음 로그인하면 비밀번호 변경 창이 자동으로 뜸.
--   (사용자가 비밀번호를 변경하면 플래그는 자동 해제됨 — index.html v2.4)
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
      -- 다음 로그인 시 비밀번호 변경 안내 플래그
      raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
        || jsonb_build_object('must_change_pw', true),
      updated_at = now()
  where id = v_target_uid;
end;
$$ language plpgsql security definer;

revoke all on function admin_reset_user_password(text, text) from public;
grant execute on function admin_reset_user_password(text, text) to authenticated;

-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 확인:
--   1. 테스트 계정 비밀번호를 관리자 패널에서 초기화
--   2. 그 임시 비밀번호로 로그인 → 비밀번호 변경 창이 자동으로 뜨면 정상
--   3. 새 비밀번호로 변경 후 재로그인 → 창이 다시 안 뜨면 정상
