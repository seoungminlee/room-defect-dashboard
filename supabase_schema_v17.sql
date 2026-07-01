-- ============================================================
-- 객실 하자관리 시스템 - v17 스키마
-- 작성일: 2026-06-29
--
-- 변경 내용:
--   1) update_logs  — 업데이트 로그 테이블 (관리자 작성, 사용자 팝업 표시 여부 포함)
--   2) app_settings — app_version 기본값 추가
--
-- 실행 전 v16 스키마가 적용되어 있어야 합니다.
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- 1. 업데이트 로그 테이블
-- ────────────────────────────────────────────────────────────
create table if not exists update_logs (
  id           bigserial primary key,
  version      text not null,              -- 버전명 (예: v1.5)
  category     text not null default '기능 추가', -- 기능 추가 | 버그 수정 | UI 개선
  title        text not null,              -- 업데이트 제목
  body         text not null,              -- 변경 내용 (줄바꿈 구분)
  show_popup   boolean not null default true,  -- 사용자 팝업 표시 여부
  created_by   uuid references auth.users(id) on delete set null,
  created_at   timestamptz not null default now()
);

comment on table update_logs is '시스템 업데이트 이력. 관리자가 작성하고 show_popup=true인 최신 항목이 사용자 팝업에 표시됨.';

-- RLS
alter table update_logs enable row level security;

create policy "로그인 사용자 업데이트 로그 조회"
  on update_logs for select
  using (auth.uid() is not null);

create policy "admin만 업데이트 로그 작성"
  on update_logs for insert
  with check (
    exists (
      select 1 from auth.users
      where id = auth.uid()
        and raw_user_meta_data->>'role' = 'admin'
    )
  );

create policy "admin만 업데이트 로그 수정"
  on update_logs for update
  using (
    exists (
      select 1 from auth.users
      where id = auth.uid()
        and raw_user_meta_data->>'role' = 'admin'
    )
  );

create policy "admin만 업데이트 로그 삭제"
  on update_logs for delete
  using (
    exists (
      select 1 from auth.users
      where id = auth.uid()
        and raw_user_meta_data->>'role' = 'admin'
    )
  );

create index if not exists idx_update_logs_created_at on update_logs(created_at desc);


-- ────────────────────────────────────────────────────────────
-- 2. app_settings — app_version 기본값 추가
-- ────────────────────────────────────────────────────────────
insert into app_settings (key, value) values
  ('app_version', 'v1.0')
on conflict (key) do nothing;


-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
-- ============================================================
