-- ============================================================
-- 객실 하자관리 시스템 - v37 직원(staff) 외주업체 등록·수정 허용
-- 작성일: 2026-09-30
-- 실행 전 v36까지 적용되어 있어야 합니다.
--
-- 배경:
--   직원이 실무에서 외주업체 서류(사업자등록증·계좌사본·계약서)를 내려받아
--   지출품의를 올리므로, 업체 등록·수정과 서류 업로드가 직원에게도 필요함.
--   (기존: v19·v25에서 외주업체는 admin 전용으로 유지)
--
-- 변경:
--   vendors        등록·수정: admin → admin+staff (can_edit)
--   vendor-docs    업로드   : admin → admin+staff (can_edit)
-- 유지:
--   vendors 삭제, vendor-docs 파일 덮어쓰기·삭제는 admin 전용
--   조회(목록·서류 열람)는 기존대로 로그인 사용자 전원
--   viewer(조회전용)는 여전히 등록·수정·업로드 불가
--
-- ★ 새 index.html(v2.7.23) 배포와 함께 적용하세요.
-- ============================================================

-- 1) vendors 테이블 정책
drop policy if exists "ins_vendors"    on vendors;
drop policy if exists "upd_vendors"    on vendors;
drop policy if exists "vendors_insert" on vendors;   -- v13 시절 이름 (남아있을 경우 대비)
drop policy if exists "vendors_update" on vendors;

create policy "ins_vendors" on vendors for insert with check (can_edit());
create policy "upd_vendors" on vendors for update using (can_edit());
-- del_vendors(admin 전용)는 변경 없음


-- 2) vendor-docs 버킷 업로드 정책
drop policy if exists "vendor_docs_insert" on storage.objects;
create policy "vendor_docs_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'vendor-docs' and can_edit());
-- vendor_docs_update / vendor_docs_delete (admin 전용)는 변경 없음


-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 실행 후 확인 (결과를 보고 아래 값과 같은지 확인):
--   select policyname, cmd, qual, with_check from pg_policies
--    where tablename = 'vendors' order by cmd;
--     → INSERT/UPDATE 행에 can_edit(), DELETE 행에 get_my_role() = 'admin'
--   select policyname, with_check from pg_policies
--    where schemaname='storage' and policyname = 'vendor_docs_insert';
--     → can_edit() 포함
--
-- 화면 확인:
--   1. staff 계정: 업체 등록·수정·서류 업로드 성공, 삭제 버튼은 안 보임
--   2. viewer 계정: 등록·수정 버튼 안 보임, 서류 열람은 가능
--   3. admin 계정: 기존과 동일
-- ============================================================
