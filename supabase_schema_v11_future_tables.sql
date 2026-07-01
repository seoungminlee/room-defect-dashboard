-- ============================================================
-- 객실 하자관리 시스템 - v11 스키마 (선구축 테이블 + 공지사항)
-- 작성일: 2026-06-23
-- 실행 전 v10 스키마가 적용되어 있어야 합니다.
--
-- [즉시 사용] announcements  — 공지사항 (대시보드 배너)
-- [선구축]    vendors         — 외주업체 마스터
--             pm_schedules    — 정기점검 스케줄
--             pm_logs         — 정기점검 실적
--             monthly_budget  — 월별 예산
--             notification_rules — 알림 규칙 (Vercel 이전 후 활성화)
-- ============================================================


-- ============================================================
-- 1) 공지사항 (즉시 사용)
--    전체 사용자가 등록 가능, 노출 기간 설정, 관리자만 삭제
-- ============================================================
create table if not exists announcements (
  id           bigint generated always as identity primary key,
  content      text not null,
  url          text,                          -- 관련 링크 (선택)
  starts_at    date not null default current_date,
  ends_at      date not null default (current_date + interval '7 days'),
  created_by   uuid references auth.users(id),
  created_by_email text,
  created_at   timestamptz not null default now()
);

alter table announcements enable row level security;

-- 인증된 사용자 전원 조회/등록 가능
create policy "auth_select_announcements" on announcements for select using (auth.role() = 'authenticated');
create policy "auth_insert_announcements" on announcements for insert with check (auth.role() = 'authenticated');
-- 수정은 본인 또는 admin
create policy "auth_update_announcements" on announcements for update
  using (auth.uid() = created_by or get_my_role() = 'admin');
-- 삭제는 본인 또는 admin
create policy "auth_delete_announcements" on announcements for delete
  using (auth.uid() = created_by or get_my_role() = 'admin');


-- ============================================================
-- 2) 외주업체 마스터 [선구축 — 화면 미구현]
--    현재 defects.vendor_name(자유텍스트)을 ID 참조로 전환 예정
-- ============================================================
create table if not exists vendors (
  id           bigint generated always as identity primary key,
  name         text not null unique,          -- 업체명
  category     text,                          -- 담당 공종 (전기, 설비 등)
  contact_name text,                          -- 담당자 이름
  contact_phone text,                         -- 연락처
  contract_start date,                        -- 계약 시작일
  contract_end   date,                        -- 계약 종료일
  note         text,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);

alter table vendors enable row level security;
create policy "auth_select_vendors" on vendors for select using (auth.role() = 'authenticated');
create policy "auth_insert_vendors" on vendors for insert with check (get_my_role() = 'admin');
create policy "auth_update_vendors" on vendors for update using (get_my_role() = 'admin');
create policy "auth_delete_vendors" on vendors for delete using (get_my_role() = 'admin');


-- ============================================================
-- 3) 정기점검 스케줄 [선구축 — 화면 미구현]
--    예방정비(PM) 항목 등록. 주기가 되면 pm_logs에 실적 기록
-- ============================================================
create table if not exists pm_schedules (
  id              bigint generated always as identity primary key,
  title           text not null,              -- 점검 항목명 (예: 에어컨 필터 교체)
  category_id     bigint references defect_categories(id),  -- 관련 공종
  target          text,                       -- 점검 대상 (예: 전 객실, 공용부)
  interval_days   int not null,               -- 점검 주기 (일 단위)
  last_done_at    date,                       -- 마지막 점검일
  next_due_at     date,                       -- 다음 예정일 (트리거 자동 계산)
  assigned_to     text,                       -- 담당자
  note            text,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);

alter table pm_schedules enable row level security;
create policy "auth_select_pm_schedules" on pm_schedules for select using (auth.role() = 'authenticated');
create policy "auth_insert_pm_schedules" on pm_schedules for insert with check (get_my_role() = 'admin');
create policy "auth_update_pm_schedules" on pm_schedules for update using (auth.role() = 'authenticated');
create policy "auth_delete_pm_schedules" on pm_schedules for delete using (get_my_role() = 'admin');

-- 점검 완료 시 next_due_at 자동 갱신 트리거
create or replace function update_pm_next_due()
returns trigger as $$
begin
  new.next_due_at := new.last_done_at + (new.interval_days || ' days')::interval;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_update_pm_next_due on pm_schedules;
create trigger trg_update_pm_next_due
  before insert or update of last_done_at on pm_schedules
  for each row execute function update_pm_next_due();


-- ============================================================
-- 4) 정기점검 실적 [선구축 — 화면 미구현]
-- ============================================================
create table if not exists pm_logs (
  id           bigint generated always as identity primary key,
  schedule_id  bigint not null references pm_schedules(id) on delete cascade,
  done_at      date not null default current_date,
  done_by      text,                          -- 점검자
  result       text,                          -- 정상 / 이상발견 / 보류
  note         text,
  defect_id    bigint references defects(id), -- 점검 중 발견된 하자 연결 (선택)
  created_at   timestamptz not null default now()
);

alter table pm_logs enable row level security;
create policy "auth_select_pm_logs" on pm_logs for select using (auth.role() = 'authenticated');
create policy "auth_insert_pm_logs" on pm_logs for insert with check (auth.role() = 'authenticated');
create policy "auth_update_pm_logs" on pm_logs for update using (auth.role() = 'authenticated');
create policy "auth_delete_pm_logs" on pm_logs for delete using (get_my_role() = 'admin');

-- pm_logs 입력 시 pm_schedules.last_done_at 자동 갱신
create or replace function sync_pm_last_done()
returns trigger as $$
begin
  update pm_schedules
  set last_done_at = new.done_at
  where id = new.schedule_id
    and (last_done_at is null or new.done_at > last_done_at);
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_sync_pm_last_done on pm_logs;
create trigger trg_sync_pm_last_done
  after insert on pm_logs
  for each row execute function sync_pm_last_done();


-- ============================================================
-- 5) 월별 예산 [선구축 — 화면 미구현]
--    예산 입력 후 defects.total_cost 집계와 대조하여 실적 산출
-- ============================================================
create table if not exists monthly_budget (
  id           bigint generated always as identity primary key,
  year         int not null,
  month        int not null check (month between 1 and 12),
  category_id  bigint references defect_categories(id),  -- null이면 전체 예산
  budget_amount numeric(14,2) not null default 0,
  note         text,
  created_at   timestamptz not null default now(),
  unique (year, month, category_id)
);

alter table monthly_budget enable row level security;
create policy "auth_select_budget" on monthly_budget for select using (auth.role() = 'authenticated');
create policy "auth_insert_budget" on monthly_budget for insert with check (get_my_role() = 'admin');
create policy "auth_update_budget" on monthly_budget for update using (get_my_role() = 'admin');
create policy "auth_delete_budget" on monthly_budget for delete using (get_my_role() = 'admin');


-- ============================================================
-- 6) 알림 규칙 [선구축 — Vercel 이전 후 활성화]
--    SLA 임박, 재고 부족 등 조건 충족 시 알림 발송 규칙
-- ============================================================
create table if not exists notification_rules (
  id           bigint generated always as identity primary key,
  rule_type    text not null,  -- 'sla_warning' | 'stock_low' | 'pm_due'
  target_type  text,           -- 'email' | 'kakao' | 'slack'
  target_value text,           -- 수신 주소 또는 웹훅 URL
  threshold    numeric,        -- 기준값 (SLA 잔여시간, 재고 수량 등)
  is_active    boolean not null default false,  -- 기본 비활성
  note         text,
  created_at   timestamptz not null default now()
);

alter table notification_rules enable row level security;
create policy "auth_select_notif_rules" on notification_rules for select using (auth.role() = 'authenticated');
create policy "auth_insert_notif_rules" on notification_rules for insert with check (get_my_role() = 'admin');
create policy "auth_update_notif_rules" on notification_rules for update using (get_my_role() = 'admin');
create policy "auth_delete_notif_rules" on notification_rules for delete using (get_my_role() = 'admin');


-- ============================================================
-- 끝. SQL Editor에 붙여넣고 Run 하세요.
--
-- 즉시 사용: announcements (공지사항)
-- 선구축 완료 (화면은 추후):
--   vendors, pm_schedules, pm_logs, monthly_budget, notification_rules
-- ============================================================
