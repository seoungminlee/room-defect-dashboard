-- ============================================================
-- 객실 하자관리 시스템 - v14 스키마
-- 작성일: 2026-06-24
--
-- 변경 내용:
--   1) defects 테이블에 하자/보수 접수 폼용 컬럼 추가
--   2) user 이름 저장/조회 RPC 함수 추가
--   3) vendors 테이블 is_registered 컬럼 추가 (v13에서 누락)
--
-- 원복 방법:
--   아래 ROLLBACK 섹션의 DROP COLUMN 문들을 실행하면
--   추가된 컬럼만 제거됩니다. 기존 데이터는 무손상입니다.
-- ============================================================


-- ============================================================
-- 1) defects 테이블 — 접수 폼 전용 컬럼 추가
-- ============================================================

-- 접수자 정보 (로그인 세션에서 자동 입력)
alter table defects add column if not exists requester_email      text;
alter table defects add column if not exists requester_name       text;

-- 시설명 (기본값: 시흥 웨이브파크 — 향후 멀티 지점 확장 대비)
alter table defects add column if not exists site_name            text default '시흥 웨이브파크';

-- 구글폼 대분류 (객실 내 시설 / 욕실·수전 / 전기·조명 등)
alter table defects add column if not exists form_category        text;

-- 구글폼 소분류 ([욕실·수전] 샤워기 등)
alter table defects add column if not exists form_location_detail text;

-- 견적 관련
alter table defects add column if not exists estimate_amount      numeric default 0;   -- VAT 포함 견적
alter table defects add column if not exists estimate_vat_excl    numeric default 0;   -- VAT 별도 견적
alter table defects add column if not exists estimate_file_url    text;                -- 견적서 파일 URL

-- 업체 관련 (추가 필드)
alter table defects add column if not exists vendor_note          text;    -- 비고업체 메모
alter table defects add column if not exists vendor_compare       text;    -- 비교업체명

-- 슬랙 발송 여부 추적
alter table defects add column if not exists slack_sent           boolean default false;
alter table defects add column if not exists slack_sent_at        timestamptz;

comment on column defects.requester_email      is '접수자 이메일 — Supabase Auth 로그인 세션에서 자동 입력';
comment on column defects.requester_name       is '접수자 이름 — user_metadata.full_name에서 자동 입력';
comment on column defects.site_name            is '시설명 (기본값: 시흥 웨이브파크)';
comment on column defects.form_category        is '구글폼 대분류 (객실 내 시설 / 욕실·수전 등)';
comment on column defects.form_location_detail is '구글폼 소분류 ([욕실·수전] 샤워기 등)';
comment on column defects.estimate_amount      is 'VAT 포함 견적액';
comment on column defects.estimate_vat_excl    is 'VAT 별도 견적액';
comment on column defects.estimate_file_url    is '견적서 파일 URL (Supabase Storage 또는 외부 링크)';
comment on column defects.vendor_note          is '비고업체 메모';
comment on column defects.vendor_compare       is '비교업체명';
comment on column defects.slack_sent           is '슬랙 발송 완료 여부';
comment on column defects.slack_sent_at        is '슬랙 발송 시각';


-- ============================================================
-- 2) vendors 테이블 — is_registered 컬럼 (v13에서 누락된 것)
-- ============================================================

alter table vendors add column if not exists is_registered boolean default false;
comment on column vendors.is_registered is '공식 거래처 등록 여부 (사업자등록증·계좌 서류 확인 완료)';


-- ============================================================
-- 3) 사용자 이름 저장/조회 RPC 함수
--    — user_metadata.full_name 을 읽고 쓰는 보안 함수
-- ============================================================

-- 본인 이름 업데이트 (누구나 자신의 이름만 변경 가능)
create or replace function set_my_display_name(display_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update auth.users
  set raw_user_meta_data =
    coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('full_name', display_name)
  where id = auth.uid();
end;
$$;

-- 본인 이름 조회
create or replace function get_my_display_name()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  select raw_user_meta_data->>'full_name'
  into v_name
  from auth.users
  where id = auth.uid();
  return v_name;
end;
$$;

-- admin: 모든 사용자 이름 포함 목록 조회 (admin_list_users 대체/보완)
create or replace function admin_list_users_with_name()
returns table(
  id          uuid,
  email       text,
  full_name   text,
  role        text,
  last_sign_in timestamptz,
  created_at  timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if get_my_role() <> 'admin' then
    raise exception 'admin only';
  end if;
  return query
  select
    u.id,
    u.email,
    u.raw_user_meta_data->>'full_name',
    coalesce(u.raw_user_meta_data->>'role', 'staff'),
    u.last_sign_in_at,
    u.created_at
  from auth.users u
  order by u.created_at desc;
end;
$$;


-- ============================================================
-- 4) 완료.
--
-- Supabase SQL Editor에서 이 파일을 실행한 뒤:
--   A) index.html을 GitHub에 push하여 배포
--
-- ============================================================
-- ROLLBACK (원복 시 아래 실행)
-- ============================================================
/*
alter table defects drop column if exists requester_email;
alter table defects drop column if exists requester_name;
alter table defects drop column if exists site_name;
alter table defects drop column if exists form_category;
alter table defects drop column if exists form_location_detail;
alter table defects drop column if exists estimate_amount;
alter table defects drop column if exists estimate_vat_excl;
alter table defects drop column if exists estimate_file_url;
alter table defects drop column if exists vendor_note;
alter table defects drop column if exists vendor_compare;
alter table defects drop column if exists slack_sent;
alter table defects drop column if exists slack_sent_at;
alter table vendors drop column if exists is_registered;
drop function if exists set_my_display_name(text);
drop function if exists get_my_display_name();
drop function if exists admin_list_users_with_name();
*/
