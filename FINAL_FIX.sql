-- ══════════════════════════════════════════════════════
--  ShiftOps — FINAL DEFINITIVE FIX
--  Run in Supabase → SQL Editor
-- ══════════════════════════════════════════════════════

-- STEP 1: Disable RLS temporarily on employees so we can clean up
-- (we'll re-enable with correct policies at the end)
alter table public.employees disable row level security;
alter table public.chat_messages disable row level security;
alter table public.shifts disable row level security;
alter table public.swaps disable row level security;
alter table public.schedule_published disable row level security;

-- STEP 2: Drop every single policy that could cause recursion
drop policy if exists "Admin can manage employees"              on public.employees;
drop policy if exists "Members can read employees"             on public.employees;
drop policy if exists "Admin can manage employees in own orgs" on public.employees;
drop policy if exists "Employees can read colleagues"          on public.employees;

drop policy if exists "Admin can manage shifts"                on public.shifts;
drop policy if exists "Members can read shifts"                on public.shifts;
drop policy if exists "Employees can read their org shifts"    on public.shifts;

drop policy if exists "Admin can manage swaps"                 on public.swaps;
drop policy if exists "Members can read swaps"                 on public.swaps;
drop policy if exists "Members can insert swaps"               on public.swaps;
drop policy if exists "Employees can read and create swaps"    on public.swaps;
drop policy if exists "Employees can read swaps"               on public.swaps;
drop policy if exists "Employees can insert swaps"             on public.swaps;

drop policy if exists "Members can read chat"                  on public.chat_messages;
drop policy if exists "Members can send chat"                  on public.chat_messages;
drop policy if exists "Org members can read chat"              on public.chat_messages;
drop policy if exists "Org members can send chat"              on public.chat_messages;

drop policy if exists "Admin can manage schedule"              on public.schedule_published;
drop policy if exists "Members can read schedule"              on public.schedule_published;
drop policy if exists "Admin can manage publish state"         on public.schedule_published;
drop policy if exists "Employees can read publish state"       on public.schedule_published;

-- STEP 3: Drop and recreate helper functions (security definer bypasses RLS)
drop function if exists public.is_org_admin(uuid);
drop function if exists public.is_org_member(uuid);

create or replace function public.is_org_admin(org uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from organizations
    where id = org and admin_id = auth.uid()
  );
$$;

create or replace function public.is_org_member(org uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from employees
    where org_id = org and user_id = auth.uid()
  );
$$;

-- STEP 4: Recreate all policies using the helper functions
-- EMPLOYEES
create policy "Admin manage employees"
  on public.employees for all
  using ( public.is_org_admin(org_id) );

create policy "Member read employees"
  on public.employees for select
  using ( public.is_org_admin(org_id) or public.is_org_member(org_id) );

-- SHIFTS
create policy "Admin manage shifts"
  on public.shifts for all
  using ( public.is_org_admin(org_id) );

create policy "Member read shifts"
  on public.shifts for select
  using ( public.is_org_admin(org_id) or public.is_org_member(org_id) );

-- SWAPS
create policy "Admin manage swaps"
  on public.swaps for all
  using ( public.is_org_admin(org_id) );

create policy "Member read swaps"
  on public.swaps for select
  using ( public.is_org_admin(org_id) or public.is_org_member(org_id) );

create policy "Member insert swaps"
  on public.swaps for insert
  with check ( public.is_org_admin(org_id) or public.is_org_member(org_id) );

-- CHAT
create policy "Member read chat"
  on public.chat_messages for select
  using ( public.is_org_admin(org_id) or public.is_org_member(org_id) );

create policy "Member send chat"
  on public.chat_messages for insert
  with check (
    auth.uid() = sender_id
    and ( public.is_org_admin(org_id) or public.is_org_member(org_id) )
  );

-- SCHEDULE
create policy "Admin manage schedule"
  on public.schedule_published for all
  using ( public.is_org_admin(org_id) );

create policy "Member read schedule"
  on public.schedule_published for select
  using ( public.is_org_admin(org_id) or public.is_org_member(org_id) );

-- STEP 5: Re-enable RLS
alter table public.employees enable row level security;
alter table public.chat_messages enable row level security;
alter table public.shifts enable row level security;
alter table public.swaps enable row level security;
alter table public.schedule_published enable row level security;

-- STEP 6: Link any unlinked employees to their auth accounts by email
update public.employees e
set user_id = u.id
from auth.users u
where lower(e.email) = lower(u.email)
  and e.user_id is null;

-- STEP 7: Create missing profiles for any auth users who don't have one
insert into public.profiles (id, first, last, role, color)
select
  u.id,
  coalesce(u.raw_user_meta_data->>'first', split_part(u.email,'@',1)),
  coalesce(u.raw_user_meta_data->>'last', ''),
  coalesce(u.raw_user_meta_data->>'role', 'employee'),
  '#3ecf8e'
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict (id) do nothing;
