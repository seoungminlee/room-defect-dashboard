-- ============================================================
-- 객실 하자관리 시스템 - v30 하자증상 마스터 테이블 신설
-- 작성일: 2026-07-06
-- 실행 전 v28까지 적용되어 있어야 합니다.
--
-- 배경:
--   하자증상(누수·누전/파손·균열/오염·변색/작동불량/소음·냄새/기타)이
--   index.html에 하드코딩되어 있어 기준정보 화면에서 추가·수정이
--   불가능했음 → 하자부위(defect_locations)와 동일한 패턴의
--   마스터 테이블을 신설하여 기준정보에서 관리 가능하게 함.
--
-- 주의: defects.symptom 컬럼(text)은 그대로 유지합니다.
--   (기존 데이터·통계·검색 로직과의 호환성을 위해 FK로 바꾸지 않고,
--    선택 목록(피커)만 이 마스터 테이블에서 가져오는 방식입니다.)
-- ============================================================


-- ============================================================
-- 1) 하자증상 마스터 테이블
-- ============================================================
create table if not exists defect_symptoms (
  id bigint generated always as identity primary key,
  name text not null unique,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table defect_symptoms enable row level security;

drop policy if exists "sel_symptoms" on defect_symptoms;
drop policy if exists "ins_symptoms" on defect_symptoms;
drop policy if exists "upd_symptoms" on defect_symptoms;
drop policy if exists "del_symptoms" on defect_symptoms;

create policy "sel_symptoms" on defect_symptoms for select using (auth.uid() is not null);
create policy "ins_symptoms" on defect_symptoms for insert with check (can_edit());
create policy "upd_symptoms" on defect_symptoms for update using (can_edit());
create policy "del_symptoms" on defect_symptoms for delete using (get_my_role() = 'admin');


-- ============================================================
-- 2) 기존 6개 고정값을 초기 데이터로 이관 (이미 있으면 건너뜀)
-- ============================================================
insert into defect_symptoms (name, sort_order)
values
  ('누수·누전', 1),
  ('파손·균열', 2),
  ('오염·변색', 3),
  ('작동불량', 4),
  ('소음·냄새', 5),
  ('기타', 6)
on conflict (name) do nothing;


-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 실행 후 확인:
--   1. defect_symptoms 테이블에 6개 행이 생성되었는지
--   2. 새 index.html 배포 후 기준정보 → 하자증상 탭에서
--      추가·수정·삭제가 정상 동작하는지
--   3. 하자 등록 폼의 하자증상 드롭다운이 이 테이블 기준으로 뜨는지
-- ============================================================
