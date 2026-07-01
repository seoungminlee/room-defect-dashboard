-- ============================================================
-- 객실 하자관리 시스템 - v18 스키마
-- 작성일: 2026-06-29
--
-- 변경 내용:
--   1) announcements.is_important 컬럼 추가
--   2) announcements RLS 정책 수정
--      - INSERT: 로그인 사용자 전체 가능
--      - is_important = true 는 admin만 설정 가능
--      - UPDATE/DELETE: 본인 작성글 또는 admin
-- ============================================================

-- ── 1. is_important 컬럼 추가 ──────────────────────────────
alter table announcements
  add column if not exists is_important boolean not null default false;

comment on column announcements.is_important is '중요 공지 여부. true이면 상단 배너에 표시. admin만 설정 가능.';

-- ── 2. INSERT 정책 교체 ────────────────────────────────────
drop policy if exists "admin만 공지 작성" on announcements;
drop policy if exists "로그인 사용자 공지 작성" on announcements;

create policy "로그인 사용자 공지 작성"
  on announcements for insert
  with check (
    auth.uid() is not null
    and (
      is_important = false
      or exists (
        select 1 from auth.users
        where id = auth.uid()
          and raw_user_meta_data->>'role' = 'admin'
      )
    )
  );

-- ── 3. UPDATE 정책 교체 ────────────────────────────────────
drop policy if exists "admin만 공지 수정" on announcements;
drop policy if exists "본인 또는 admin 공지 수정" on announcements;

create policy "본인 또는 admin 공지 수정"
  on announcements for update
  using (
    created_by = auth.uid()
    or exists (
      select 1 from auth.users
      where id = auth.uid()
        and raw_user_meta_data->>'role' = 'admin'
    )
  )
  with check (
    is_important = false
    or exists (
      select 1 from auth.users
      where id = auth.uid()
        and raw_user_meta_data->>'role' = 'admin'
    )
  );

-- ── 4. DELETE 정책 교체 ────────────────────────────────────
drop policy if exists "admin만 공지 삭제" on announcements;
drop policy if exists "본인 또는 admin 공지 삭제" on announcements;

create policy "본인 또는 admin 공지 삭제"
  on announcements for delete
  using (
    created_by = auth.uid()
    or exists (
      select 1 from auth.users
      where id = auth.uid()
        and raw_user_meta_data->>'role' = 'admin'
    )
  );

-- ============================================================
-- 끝. Supabase SQL Editor에 붙여넣고 Run 하세요.
-- ============================================================
