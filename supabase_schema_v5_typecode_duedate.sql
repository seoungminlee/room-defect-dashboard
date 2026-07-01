-- ============================================================
-- 객실 하자관리 시스템 - v5 추가 스키마 (타입코드 / 예정일)
-- 작성일: 2026-06-23
-- 설명: 기존 v1~v4 스키마는 그대로 두고 이 파일만 추가로 실행하세요.
--       기존 데이터는 건드리지 않고 새 컬럼만 추가합니다.
-- ============================================================

-- ------------------------------------------------------------
-- 1) room_types에 영문 타입코드 추가
--    예: 스튜디오 로프트 -> SL, 스튜디오 로프트 패밀리 -> SLF
--    추후 '타입코드로 검색해서 그 타입 전체 하자를 모아보는' 기능의 기반이 됩니다.
-- ------------------------------------------------------------
alter table room_types add column if not exists type_code text;
create unique index if not exists idx_room_types_code on room_types(type_code) where type_code is not null;

-- ------------------------------------------------------------
-- 2) defects에 예정일(처리완료 목표일) 추가
-- ------------------------------------------------------------
alter table defects add column if not exists due_date date;

-- ------------------------------------------------------------
-- 3) 직원 마스터
--    담당자/등록자를 자유텍스트로 매번 입력하지 않고, 미리 등록해둔
--    직원 목록에서 드롭다운으로 선택할 수 있게 합니다.
--    (로그인 계정과는 무관한 단순 참조용 목록입니다.)
-- ------------------------------------------------------------
create table if not exists employees (
  id bigint generated always as identity primary key,
  name text not null unique,
  role text,                      -- 직책/역할 (선택, 예: 시설팀, 매니저)
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table employees enable row level security;
create policy "anon_select_employees" on employees for select using (true);
create policy "anon_insert_employees" on employees for insert with check (true);
create policy "anon_update_employees" on employees for update using (true);
create policy "anon_delete_employees" on employees for delete using (true);

-- ============================================================
-- 끝. 여기까지 SQL Editor에 붙여넣고 Run 누르세요.
-- ============================================================
