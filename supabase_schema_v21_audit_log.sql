-- ============================================================
-- 객실 하자관리 시스템 - v21 범용 감사 로그
-- 작성일: 2026-07-02
-- 실행 전 v20까지 적용되어 있어야 합니다.
--
-- 내용:
--   1) audit_logs 테이블 신설 — 전 주요 테이블의 등록/수정/삭제를
--      "누가·언제·무엇을" 수준으로 기록 (admin만 열람)
--   2) 기존 defect_audit_log(하자 전용, v8)의 데이터를 이관 후 대체
--   3) reset_operation_data 실행 자체도 감사 로그에 기록
--
-- ★ 이 SQL과 함께 새 index.html 배포가 필요합니다.
--   (수정이력 탭이 새 테이블을 조회하도록 변경됨)
-- ============================================================


-- ============================================================
-- 1) audit_logs 테이블
-- ============================================================
create table if not exists audit_logs (
  id          bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  user_id     uuid,                -- 행위자 (auth.uid())
  user_email  text,                -- 행위자 이메일 (조회 편의)
  action      text not null,      -- 'INSERT' | 'UPDATE' | 'DELETE' | 'RESET'
  table_name  text not null,      -- 대상 테이블
  record_id   text,               -- 대상 row id (uuid/bigint 혼재 대응 위해 text)
  old_data    jsonb,              -- 변경 전 (UPDATE/DELETE)
  new_data    jsonb               -- 변경 후 (INSERT/UPDATE)
);

create index if not exists idx_audit_logs_occurred on audit_logs (occurred_at desc);
create index if not exists idx_audit_logs_table on audit_logs (table_name, occurred_at desc);

alter table audit_logs enable row level security;

-- admin만 조회. insert/update/delete 정책 없음 → 트리거(security definer)로만 적재
drop policy if exists "sel_audit_logs" on audit_logs;
create policy "sel_audit_logs" on audit_logs
  for select using (get_my_role() = 'admin');


-- ============================================================
-- 2) 범용 감사 트리거 함수
-- ============================================================
create or replace function audit_row_change()
returns trigger as $$
declare
  v_email text;
  v_id    text;
begin
  select email into v_email from auth.users where id = auth.uid();

  if (tg_op = 'DELETE') then
    v_id := (to_jsonb(old) ->> 'id');
    insert into audit_logs (user_id, user_email, action, table_name, record_id, old_data)
    values (auth.uid(), v_email, tg_op, tg_table_name, v_id, to_jsonb(old));
    return old;
  elsif (tg_op = 'UPDATE') then
    v_id := (to_jsonb(new) ->> 'id');
    insert into audit_logs (user_id, user_email, action, table_name, record_id, old_data, new_data)
    values (auth.uid(), v_email, tg_op, tg_table_name, v_id, to_jsonb(old), to_jsonb(new));
    return new;
  else
    v_id := (to_jsonb(new) ->> 'id');
    insert into audit_logs (user_id, user_email, action, table_name, record_id, new_data)
    values (auth.uid(), v_email, tg_op, tg_table_name, v_id, to_jsonb(new));
    return new;
  end if;
end;
$$ language plpgsql security definer;


-- ============================================================
-- 3) 주요 테이블에 트리거 부착
--    (하자·비용·재고·마스터데이터·설정 — 이력성 테이블은 제외)
-- ============================================================
do $$
declare
  t text;
begin
  foreach t in array array[
    'defects','defect_parts_used',
    'part_stock_in','part_stock_out','part_stock_adjustments',
    'rooms','room_types','defect_parts','defect_categories','defect_locations',
    'employees','vendors','monthly_budget','system_settings','app_settings',
    'announcements'
  ]
  loop
    execute format('drop trigger if exists trg_audit_%I on %I', t, t);
    execute format(
      'create trigger trg_audit_%I after insert or update or delete on %I
       for each row execute function audit_row_change()', t, t);
  end loop;
end $$;


-- ============================================================
-- 4) 기존 defect_audit_log(v8) 이관 후 정리
-- ============================================================
insert into audit_logs (occurred_at, user_id, user_email, action, table_name, record_id, old_data, new_data)
select changed_at, changed_by, changed_by_email, action, 'defects', defect_id::text, before_data, after_data
from defect_audit_log;

drop trigger if exists trg_log_defect_change on defects;
drop function if exists log_defect_change();
drop table if exists defect_audit_log;


-- ============================================================
-- 5) reset_operation_data — 초기화 실행도 감사 로그에 기록
--    (audit_logs 자체는 초기화 대상에서 제외 → 기록 보존)
-- ============================================================
create or replace function reset_operation_data()
returns void as $$
declare
  v_email text;
begin
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role', 'viewer') <> 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  select email into v_email from auth.users where id = auth.uid();
  insert into audit_logs (user_id, user_email, action, table_name, record_id)
  values (auth.uid(), v_email, 'RESET', '(운영 데이터 전체)', null);

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

revoke all on function reset_operation_data() from public;
grant execute on function reset_operation_data() to authenticated;


-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 참고 (보관 기간):
--   로그는 무한 적재됩니다. 1~2년 후 용량이 커지면 아래로 정리:
--   delete from audit_logs where occurred_at < now() - interval '1 year';
--
-- 실행 후 체크리스트:
--   1. 새 index.html 배포
--   2. 하자 등록/수정 → 관리자 탭 > 수정이력에 기록되는지 확인
--   3. 부품·객실·업체 수정도 기록되는지 확인
--   4. staff 계정에서는 수정이력 탭 데이터가 안 보이는지 확인
-- ============================================================
