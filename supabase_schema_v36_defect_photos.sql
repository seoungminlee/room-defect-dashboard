-- ============================================================
-- 객실 하자관리 시스템 - v36 하자 사진 첨부 기능
-- 작성일: 2026-07-24
-- 실행 전 v35까지 적용되어 있어야 합니다.
--
-- 배경:
--   하자 등록/처리 중 현장 사진을 첨부할 수 있는 기능 추가.
--   defect_photos 테이블은 초기 스키마(supabase_schema.sql)부터 존재했지만
--   실제 업로드 기능은 이번에 처음 구현.
--
--   Supabase 무료 플랜(스토리지 1GB, 월 egress 5GB) 제약을 감안해:
--     - 업로드 전 브라우저에서 리사이즈+JPEG 압축 (index.html에서 처리, 서버 작업 아님)
--     - 하자 1건당 최대 5장으로 앱 단에서 제한
--     - 원본이 아닌 압축본만 저장 (장당 약 150~400KB 예상 — 실측치 아님, 사진 내용에 따라 다름)
--
--   버킷은 비공개(private)로 생성 — 사진 URL은 로그인 사용자에게만
--   10분 유효 서명 URL로 발급됩니다 (vendor-docs, hub-docs와 동일 방식).
--
-- ★ 이 SQL과 함께 새 index.html 배포가 필요합니다.
-- ============================================================

-- ============================================================
-- 1) defect_photos 테이블에 업로더 기록 컬럼 추가 (책임 추적용)
-- ============================================================
alter table defect_photos add column if not exists uploaded_by text;
comment on column defect_photos.photo_url is '비공개 버킷(defect-photos) 내 객체 경로. 공개 URL 아님 — 조회 시 서명 URL을 별도 발급';
comment on column defect_photos.uploaded_by is '업로드한 사용자 표시 이름';


-- ============================================================
-- 2) 비공개 스토리지 버킷 생성
-- ============================================================
insert into storage.buckets (id, name, public)
values ('defect-photos', 'defect-photos', false)
on conflict (id) do nothing;


-- ============================================================
-- 3) storage.objects RLS 정책 (defect-photos 전용)
--    조회: 로그인 사용자 (서명 URL 발급에 필요)
--    업로드·삭제: staff/admin (viewer 제외) — 하자 삭제 권한과 동일 수준
-- ============================================================
drop policy if exists "defect_photos_select" on storage.objects;
create policy "defect_photos_select" on storage.objects
  for select to authenticated
  using (bucket_id = 'defect-photos');

drop policy if exists "defect_photos_insert" on storage.objects;
create policy "defect_photos_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'defect-photos' and can_edit());

drop policy if exists "defect_photos_delete" on storage.objects;
create policy "defect_photos_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'defect-photos' and can_edit());


-- ============================================================
-- 4) defect_photos 테이블 RLS는 v19에서 이미 설정되어 있음 (변경 없음)
--    sel_photos: 로그인 사용자 전체 조회 가능
--    ins_photos / del_photos: can_edit() (staff/admin)
--    ※ 그대로 사용하되, 아래 조회로 존재 확인만 합니다.
-- ============================================================


-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 실행 후 확인:
--   1. 새 index.html 배포
--   2. 아래 두 줄의 결과가 각각 1, 3(select/insert/delete)이면 정상
--      select count(*) as bucket_created from storage.buckets where id = 'defect-photos';
--      select count(*) as policies_created from pg_policies
--        where schemaname='storage' and tablename='objects' and policyname like 'defect_photos_%';
--   3. staff 계정으로 하자 상세보기 → 사진 추가 → 압축된 사진이 정상 업로드/표시되는지 확인
--   4. viewer 계정으로는 "사진 추가" 버튼 자체가 안 보이는지 확인
--   5. 사진 삭제 후 목록에서 즉시 사라지는지 확인
-- ============================================================
