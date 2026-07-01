-- ============================================================
-- 객실 하자관리 시스템 - v13 스키마
-- 작성일: 2026-06-23
--
-- 변경 내용:
--   1) vendors 테이블 확장 (담당자, 연락처, 업무범위, 서류 URL 3종)
--   2) vendor_docs 스토리지 버킷 생성 (업체 서류 파일용)
--   3) 반복하자 요약 뷰 생성 (객실별·증상별 이력 집계)
--   4) RLS 정책 추가
-- ============================================================


-- ============================================================
-- 1) vendors 테이블 확장
--    (기존 vendors 테이블이 없으면 신규 생성,
--     있으면 컬럼만 추가)
-- ============================================================

create table if not exists vendors (
  id            bigserial primary key,
  name          text        not null,
  scope         text,                       -- 어떤 하자/업무를 담당하는 업체인지 (예: 누수·배관, 전기·조명)
  manager_name  text,                       -- 담당자 이름 (선택)
  phone         text,                       -- 연락처
  email         text,                       -- 이메일 (선택)
  note          text,                       -- 메모
  doc_biz_reg   text,                       -- 사업자등록증 파일 URL (Supabase Storage public URL)
  doc_account   text,                       -- 계좌사본 파일 URL
  doc_contract  text,                       -- 계약서 파일 URL
  is_active     boolean     default true,
  created_at    timestamptz default now()
);

-- 기존 테이블에 컬럼이 없으면 추가 (이미 있으면 오류 없음)
alter table vendors add column if not exists scope        text;
alter table vendors add column if not exists manager_name text;
alter table vendors add column if not exists phone        text;
alter table vendors add column if not exists email        text;
alter table vendors add column if not exists note         text;
alter table vendors add column if not exists doc_biz_reg  text;
alter table vendors add column if not exists doc_account  text;
alter table vendors add column if not exists doc_contract text;
alter table vendors add column if not exists is_active      boolean default true;
alter table vendors add column if not exists is_registered  boolean default false;

comment on column vendors.scope        is '담당 업무 범위 (예: 누수·배관, 전기·조명, 도배·도장)';
comment on column vendors.doc_biz_reg  is '사업자등록증 — Supabase Storage vendor-docs 버킷 public URL';
comment on column vendors.doc_account  is '계좌사본 — Supabase Storage vendor-docs 버킷 public URL';
comment on column vendors.doc_contract is '계약서 — Supabase Storage vendor-docs 버킷 public URL';


-- ============================================================
-- 2) RLS 정책 (vendors)
-- ============================================================

alter table vendors enable row level security;

-- staff·admin 모두 조회 가능
drop policy if exists "vendors_select" on vendors;
create policy "vendors_select" on vendors
  for select using (auth.role() = 'authenticated');

-- admin만 삽입/수정/삭제
drop policy if exists "vendors_insert" on vendors;
create policy "vendors_insert" on vendors
  for insert with check (get_my_role() = 'admin');

drop policy if exists "vendors_update" on vendors;
create policy "vendors_update" on vendors
  for update using (get_my_role() = 'admin');

drop policy if exists "vendors_delete" on vendors;
create policy "vendors_delete" on vendors
  for delete using (get_my_role() = 'admin');


-- ============================================================
-- 3) 반복하자 집계 뷰
--    — 같은 객실(room_id) + 같은 증상(symptom) 조합의
--      전체 이력을 집계하여 반복 패턴을 빠르게 조회
-- ============================================================

create or replace view v_repeat_defects as
select
  d.room_id,
  r.room_number,
  r.room_type,
  d.symptom,
  count(*)                                          as total_count,
  sum(case when d.status = '완료' then 1 else 0 end) as done_count,
  sum(d.total_cost)                                 as total_cost,
  max(d.created_at)                                 as last_occurred_at,
  min(d.created_at)                                 as first_occurred_at
from defects d
join rooms r on r.id = d.room_id
where d.symptom is not null
group by d.room_id, r.room_number, r.room_type, d.symptom
having count(*) >= 2           -- 2회 이상 발생한 경우만
order by total_count desc, last_occurred_at desc;

comment on view v_repeat_defects is
  '동일 객실·증상 조합이 2회 이상 발생한 반복하자 목록. '
  'total_count가 높을수록 구조적 문제 가능성이 높음.';


-- ============================================================
-- 4) 완료.
--
-- 이후 작업:
--   A) Supabase Dashboard → Storage → New bucket
--      이름: vendor-docs
--      Public: ON (또는 Authenticated만 접근하려면 OFF 후 RLS 설정)
--
--   B) index.html을 GitHub에 배포하면 외주업체 탭과
--      반복하자 감지, 월별 비용 집계가 활성화됩니다.
-- ============================================================
