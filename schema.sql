-- ═══════════════════════════════════════════
-- ShiftOps CLEAN SCHEMA (WORKING VERSION)
-- Paste ALL and run once
-- ═══════════════════════════════════════════

-- Enable UUID
create extension if not exists "pgcrypto";

-- ───────────────────────────────────────────
-- PROFILES
-- ───────────────────────────────────────────
create table if not exists public.profiles (
  id uuid primary key,
  first text not null,
  last text not null,
  phone text,
  role text default 'employee',
  color text default '#f0a500',
  created_at timestamptz default now()
);

-- ───────────────────────────────────────────
-- ORGANIZATIONS
-- ───────────────────────────────────────────
create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  icon text default '🏢',
  admin_id uuid,
  created_at timestamptz default now()
);

-- ───────────────────────────────────────────
-- EMPLOYEES  (CREATE EARLY — IMPORTANT)
-- ───────────────────────────────────────────
create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  org_id uuid,
  user_id uuid,
  first text not null,
  last text not null,
  role text default 'staff',
  department text,
  email text not null,
  phone text,
  status text default 'active',
  color text default '#3d8ef8',
  created_at timestamptz default now()
);

-- ───────────────────────────────────────────
-- SHIFTS
-- ───────────────────────────────────────────
create table if not exists public.shifts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid,
  employee_id uuid,
  day text,
  shift_type text default 'morning',
  start_time text,
  end_time text,
  week_offset integer default 0,
  note text,
  created_at timestamptz default now()
);

-- ───────────────────────────────────────────
-- SCHEDULE PUBLISHED
-- ───────────────────────────────────────────
create table if not exists public.schedule_published (
  id uuid primary key default gen_random_uuid(),
  org_id uuid,
  week_offset integer default 0,
  published boolean default false,
  updated_at timestamptz default now(),
  unique(org_id, week_offset)
);

-- ───────────────────────────────────────────
-- SWAPS
-- ───────────────────────────────────────────
create table if not exists public.swaps (
  id uuid primary key default gen_random_uuid(),
  org_id uuid,
  from_employee_id uuid,
  to_employee_id uuid,
  day text,
  shift_type text,
  swap_date date,
  reason text,
  status text default 'pending',
  created_at timestamptz default now()
);

-- ───────────────────────────────────────────
-- CHAT
-- ───────────────────────────────────────────
create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  org_id uuid,
  sender_id uuid,
  sender_name text,
  room text default 'general',
  text text,
  color text default '#3d8ef8',
  created_at timestamptz default now()
);

-- ───────────────────────────────────────────
-- NOTIFICATIONS
-- ───────────────────────────────────────────
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  title text,
  description text,
  icon text default '🔔',
  read boolean default false,
  created_at timestamptz default now()
);

-- ───────────────────────────────────────────
-- INVITE CODES
-- ───────────────────────────────────────────
create table if not exists public.invite_codes (
  id uuid primary key default gen_random_uuid(),
  code text unique,
  org_id uuid,
  role text default 'staff',
  created_by uuid,
  for_email text,
  used boolean default false,
  created_at timestamptz default now()
);

-- ═══════════════════════════════════════════
-- DISABLE RLS (FOR TESTING)
-- ═══════════════════════════════════════════

alter table profiles disable row level security;
alter table organizations disable row level security;
alter table employees disable row level security;
alter table shifts disable row level security;
alter table swaps disable row level security;
alter table notifications disable row level security;
alter table invite_codes disable row level security;
alter table chat_messages disable row level security;
alter table schedule_published disable row level security;

-- ═══════════════════════════════════════════
-- REALTIME (optional)
-- ═══════════════════════════════════════════
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.notifications;