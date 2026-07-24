-- ============================================================
-- v29 : 모(母) 대시보드 — 문서보관소 · 주기업무 테이블/버킷/보안
-- 실행 위치: Supabase → SQL Editor → New query → 전체 붙여넣기 → Run
-- 원칙: 기존 하자관리(M3) 테이블·정책은 일절 건드리지 않음 (신규만 추가)
-- 전제: v19에서 만든 get_my_role(), can_edit() 헬퍼 함수 사용
-- ============================================================

-- ─────────────────────────────
-- 1. 문서보관소
-- ─────────────────────────────
create table if not exists public.hub_documents (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,                -- 원본 파일명
  category      text not null default '기타',  -- 분류 (계약·협약 / 정산·비용 / 인수인계 / 매뉴얼·양식 / 기타)
  storage_path  text not null,                -- hub-docs 버킷 내 경로
  uploaded_by   text not null,                -- 등록자 표시 이름
  created_at    timestamptz not null default now()
);

alter table public.hub_documents enable row level security;

drop policy if exists "hub_documents_select" on public.hub_documents;
create policy "hub_documents_select" on public.hub_documents
  for select to authenticated using (true);           -- 로그인한 구성원 전원 조회 (viewer 포함)

drop policy if exists "hub_documents_insert" on public.hub_documents;
create policy "hub_documents_insert" on public.hub_documents
  for insert to authenticated with check (can_edit()); -- staff/admin 등록

drop policy if exists "hub_documents_delete" on public.hub_documents;
create policy "hub_documents_delete" on public.hub_documents
  for delete to authenticated using (get_my_role() = 'admin'); -- 삭제는 admin만

-- ─────────────────────────────
-- 2. 주기업무 (항목)
-- ─────────────────────────────
create table if not exists public.hub_duty_tasks (
  id         uuid primary key default gen_random_uuid(),
  title      text not null,                                          -- 업무명
  cycle      text not null check (cycle in ('monthly','yearly')),    -- 매월 / 연간
  due_label  text,                                                   -- 시기 표시 (예: 매월 5일, 1월)
  sort       bigint not null default 0,
  created_at timestamptz not null default now()
);

alter table public.hub_duty_tasks enable row level security;

drop policy if exists "hub_duty_tasks_select" on public.hub_duty_tasks;
create policy "hub_duty_tasks_select" on public.hub_duty_tasks
  for select to authenticated using (true);

drop policy if exists "hub_duty_tasks_write" on public.hub_duty_tasks;
create policy "hub_duty_tasks_write" on public.hub_duty_tasks
  for all to authenticated
  using (get_my_role() = 'admin') with check (get_my_role() = 'admin'); -- 항목 관리는 admin만

-- ─────────────────────────────
-- 3. 주기업무 (완료 체크 기록)
-- ─────────────────────────────
create table if not exists public.hub_duty_checks (
  id          uuid primary key default gen_random_uuid(),
  task_id     uuid not null references public.hub_duty_tasks(id) on delete cascade,
  period      text not null,                 -- 월간: '2026-07' / 연간: '2026'
  checked_by  text not null,                 -- 완료자 표시 이름
  checked_at  timestamptz not null default now(),
  unique (task_id, period)                   -- 같은 기간 중복 체크 방지
);

alter table public.hub_duty_checks enable row level security;

drop policy if exists "hub_duty_checks_select" on public.hub_duty_checks;
create policy "hub_duty_checks_select" on public.hub_duty_checks
  for select to authenticated using (true);

drop policy if exists "hub_duty_checks_insert" on public.hub_duty_checks;
create policy "hub_duty_checks_insert" on public.hub_duty_checks
  for insert to authenticated with check (can_edit()); -- 체크는 staff/admin

drop policy if exists "hub_duty_checks_delete" on public.hub_duty_checks;
create policy "hub_duty_checks_delete" on public.hub_duty_checks
  for delete to authenticated using (can_edit());       -- 체크 해제도 staff/admin

-- ─────────────────────────────
-- 4. 문서 저장용 비공개 버킷 (vendor-docs와 동일한 비공개 방식)
-- ─────────────────────────────
insert into storage.buckets (id, name, public)
values ('hub-docs', 'hub-docs', false)
on conflict (id) do nothing;

drop policy if exists "hub_docs_read" on storage.objects;
create policy "hub_docs_read" on storage.objects
  for select to authenticated
  using (bucket_id = 'hub-docs');                       -- 열람(서명 URL 발급)은 로그인 구성원

drop policy if exists "hub_docs_upload" on storage.objects;
create policy "hub_docs_upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'hub-docs' and can_edit());   -- 업로드는 staff/admin

drop policy if exists "hub_docs_delete" on storage.objects;
create policy "hub_docs_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'hub-docs' and get_my_role() = 'admin'); -- 삭제는 admin

-- ============================================================
-- 실행 후 확인: 아래 두 줄의 결과가 각각 3, 1이면 정상
-- ============================================================
select count(*) as new_tables from information_schema.tables
 where table_schema='public' and table_name in ('hub_documents','hub_duty_tasks','hub_duty_checks');
select count(*) as new_bucket from storage.buckets where id = 'hub-docs';
