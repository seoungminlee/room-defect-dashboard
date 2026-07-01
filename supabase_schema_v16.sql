-- ============================================================
-- 객실 하자관리 시스템 - v16 스키마
-- 작성일: 2026-06-29
--
-- 변경 내용:
--   1) defect_status_logs  — 상태 변경 이력 테이블
--   2) defect_comments     — 하자 메모/코멘트 테이블
--   3) app_settings        — 앱 전역 설정 테이블 (처리기한 임박 기준일 등)
--   4) v_defect_summary    — 모 대시보드 연동용 요약 뷰
--
-- 실행 전 v15 스키마가 적용되어 있어야 합니다.
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- 1. 상태 변경 이력 테이블
-- ────────────────────────────────────────────────────────────
create table if not exists defect_status_logs (
  id            bigserial primary key,
  defect_id     bigint not null references defects(id) on delete cascade,
  from_status   text,                        -- 변경 전 상태 (최초 등록 시 null)
  to_status     text not null,               -- 변경 후 상태
  changed_by    uuid references auth.users(id) on delete set null,
  changed_by_name text,                      -- 표시용 이름 (user_metadata.display_name)
  changed_at    timestamptz not null default now(),
  note          text                         -- 상태 변경 시 간단 메모 (선택)
);

comment on table defect_status_logs is '하자 상태 변경 이력. 평균 처리일(접수→완료) 계산에 활용.';
comment on column defect_status_logs.from_status is '변경 전 상태. 최초 등록(접수)은 null.';
comment on column defect_status_logs.note is '상태 변경 시 남기는 선택 메모.';

-- RLS
alter table defect_status_logs enable row level security;

create policy "로그인 사용자 전체 조회"
  on defect_status_logs for select
  using (auth.uid() is not null);

create policy "로그인 사용자 이력 등록"
  on defect_status_logs for insert
  with check (auth.uid() is not null);

-- 인덱스
create index if not exists idx_status_logs_defect_id on defect_status_logs(defect_id);
create index if not exists idx_status_logs_changed_at on defect_status_logs(changed_at desc);


-- ────────────────────────────────────────────────────────────
-- 2. 하자 메모/코멘트 테이블
-- ────────────────────────────────────────────────────────────
create table if not exists defect_comments (
  id            bigserial primary key,
  defect_id     bigint not null references defects(id) on delete cascade,
  author_id     uuid references auth.users(id) on delete set null,
  author_name   text,                        -- 표시용 이름
  body          text not null,               -- 코멘트 본문
  created_at    timestamptz not null default now()
);

comment on table defect_comments is '하자별 처리 메모 및 코멘트.';

alter table defect_comments enable row level security;

create policy "로그인 사용자 코멘트 조회"
  on defect_comments for select
  using (auth.uid() is not null);

create policy "로그인 사용자 코멘트 등록"
  on defect_comments for insert
  with check (auth.uid() is not null);

create policy "본인 코멘트 삭제"
  on defect_comments for delete
  using (auth.uid() = author_id);

create index if not exists idx_comments_defect_id on defect_comments(defect_id);


-- ────────────────────────────────────────────────────────────
-- 3. 앱 전역 설정 테이블
-- ────────────────────────────────────────────────────────────
create table if not exists app_settings (
  key   text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

comment on table app_settings is '앱 전역 설정값. 관리자 페이지에서 수정.';

-- RLS: 조회는 전체, 수정은 admin만
alter table app_settings enable row level security;

create policy "로그인 사용자 설정 조회"
  on app_settings for select
  using (auth.uid() is not null);

create policy "admin만 설정 수정"
  on app_settings for all
  using (
    exists (
      select 1 from auth.users
      where id = auth.uid()
        and raw_user_meta_data->>'role' = 'admin'
    )
  );

-- 기본값 삽입
insert into app_settings (key, value) values
  ('deadline_alert_days', '3')   -- 처리기한 임박 알림 기준일 (기본 3일 전)
on conflict (key) do nothing;


-- ────────────────────────────────────────────────────────────
-- 4. 모 대시보드 연동용 요약 뷰
-- ────────────────────────────────────────────────────────────
create or replace view v_defect_summary as
select
  -- 전체 현황
  count(*)                                                        as total_count,
  count(*) filter (where status not in ('완료','보류'))            as open_count,
  count(*) filter (where status = '완료')                         as done_count,
  count(*) filter (where priority = '긴급' and status != '완료')  as urgent_count,

  -- 방막 현황
  count(*) filter (where is_vacant = true and status != '완료') as blocked_room_count,

  -- 이번달 완료
  count(*) filter (
    where status = '완료'
      and updated_at >= date_trunc('month', now())
  )                                                               as done_this_month,

  -- 처리기한 임박 (오늘 기준 3일 이내, 미완료)
  count(*) filter (
    where status not in ('완료','보류')
      and due_date is not null
      and due_date between current_date and current_date + interval '3 days'
  )                                                               as deadline_soon_count,

  -- 평균 처리일 (접수→완료, 완료된 하자 기준)
  round(
    avg(
      extract(epoch from (
        (select min(sl.changed_at)
         from defect_status_logs sl
         where sl.defect_id = d.id and sl.to_status = '완료')
        -
        (select min(sl2.changed_at)
         from defect_status_logs sl2
         where sl2.defect_id = d.id and sl2.from_status is null)
      )) / 86400
    ) filter (where status = '완료')
  , 1)                                                            as avg_days_to_complete,

  now()                                                           as calculated_at
from defects d;

comment on view v_defect_summary is '모 대시보드 연동용 하자관리 요약 지표. SELECT 1회로 핵심 KPI 전체 조회 가능.';

-- 조회 권한 (로그인 사용자 전체)
grant select on v_defect_summary to authenticated;


-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
-- ============================================================
