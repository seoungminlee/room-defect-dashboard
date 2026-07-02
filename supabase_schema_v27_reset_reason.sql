-- ============================================================
-- 객실 하자관리 시스템 - v27 초기화 사유 기록
-- 작성일: 2026-07-02
-- 실행 전 v26까지 적용되어 있어야 합니다.
--
-- 내용:
--   운영 데이터 초기화 시 사유를 필수로 받아
--   실행자·이메일·일시와 함께 감사 로그에 기록.
--   (수정이력 탭에서 "⚠️ 초기화 — 사유: ..." 형태로 표시됨)
-- ============================================================

-- 기존 무인자 버전 제거 (시그니처 변경)
drop function if exists reset_operation_data();

create or replace function reset_operation_data(reset_reason text default null)
returns void as $$
declare
  v_email text;
begin
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role', 'viewer') <> 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  if reset_reason is null or length(trim(reset_reason)) = 0 then
    raise exception '초기화 사유를 입력해야 합니다.';
  end if;

  select email into v_email from auth.users where id = auth.uid();
  insert into audit_logs (user_id, user_email, action, table_name, record_id, new_data)
  values (auth.uid(), v_email, 'RESET', '(운영 데이터 전체)', null,
          jsonb_build_object('reason', trim(reset_reason)));

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

  update defect_parts set current_stock = 0 where id is not null;
end;
$$ language plpgsql security definer;

revoke all on function reset_operation_data(text) from public;
grant execute on function reset_operation_data(text) to authenticated;

-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 확인:
--   관리자 탭 > 데이터 초기화 실행 시 사유 입력창이 뜨고,
--   수정이력 탭에 "⚠️ 초기화 — 사유: ..." 로 남는지 확인.
--   (초기화해도 감사 로그 자체는 보존됨)
-- ============================================================
