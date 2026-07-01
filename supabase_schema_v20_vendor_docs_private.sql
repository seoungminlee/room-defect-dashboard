-- ============================================================
-- 객실 하자관리 시스템 - v20 vendor-docs 버킷 비공개 전환
-- 작성일: 2026-07-02
-- 실행 전 v19가 적용되어 있어야 합니다.
--
-- 해결하는 취약점 [H-2]:
--   사업자등록증·계좌사본·계약서가 공개 버킷에 있어
--   URL만 알면 로그인 없이 누구나 열람 가능했음
--   → 버킷 비공개 전환 + 로그인 사용자만 서명 URL로 열람
--
-- ★ 이 SQL과 함께 새 index.html 배포가 필요합니다.
--   (구버전 index.html은 공개 URL 방식이라 문서가 안 열립니다)
-- ============================================================


-- ============================================================
-- 1) vendors 테이블의 기존 공개 URL → 파일 경로로 변환
--    예: https://xxx.supabase.co/storage/v1/object/public/vendor-docs/vendor_123_bizreg.pdf
--        → vendor_123_bizreg.pdf
-- ============================================================
update vendors
set doc_biz_reg = regexp_replace(doc_biz_reg, '^.*/object/(public/)?vendor-docs/', '')
where doc_biz_reg like 'http%';

update vendors
set doc_account = regexp_replace(doc_account, '^.*/object/(public/)?vendor-docs/', '')
where doc_account like 'http%';

update vendors
set doc_contract = regexp_replace(doc_contract, '^.*/object/(public/)?vendor-docs/', '')
where doc_contract like 'http%';


-- ============================================================
-- 2) 버킷 비공개 전환
-- ============================================================
update storage.buckets set public = false where id = 'vendor-docs';


-- ============================================================
-- 3) storage.objects RLS 정책 (vendor-docs 전용)
--    조회: 로그인 사용자 (서명 URL 생성에 필요)
--    업로드·수정·삭제: admin만 (업체 관리 자체가 admin 권한이므로)
-- ============================================================
do $$
declare p record;
begin
  for p in
    select policyname from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname like 'vendor_docs_%'
  loop
    execute format('drop policy if exists %I on storage.objects', p.policyname);
  end loop;
end $$;

create policy "vendor_docs_select" on storage.objects
  for select to authenticated
  using (bucket_id = 'vendor-docs');

create policy "vendor_docs_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'vendor-docs' and get_my_role() = 'admin');

create policy "vendor_docs_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'vendor-docs' and get_my_role() = 'admin');

create policy "vendor_docs_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'vendor-docs' and get_my_role() = 'admin');


-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 실행 후 체크리스트:
--   1. 새 index.html 배포
--   2. 로그인 상태에서 외주업체 탭 → 문서 링크 클릭 → 정상 열람 확인
--   3. 로그아웃(시크릿 창)에서 기존 공개 URL 직접 접속 → 열람 불가 확인
--   4. admin으로 업체 서류 신규 업로드 → 정상 동작 확인
-- ============================================================
