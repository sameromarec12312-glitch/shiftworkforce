-- ══════════════════════════════════════════════════════
--  ShiftOps — Final Join Fix
--  Run in Supabase → SQL Editor
-- ══════════════════════════════════════════════════════

-- 1. Trigger: auto-create profile on new signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, first, last, phone, role, color)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'first', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'last', ''),
    new.raw_user_meta_data->>'phone',
    coalesce(new.raw_user_meta_data->>'role', 'employee'),
    '#3ecf8e'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 2. Trigger: auto-link employee record by email on signup
create or replace function public.handle_new_user_link_employee()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.employees
  set user_id = new.id
  where lower(email) = lower(new.email)
    and user_id is null;
  return new;
end;
$$;

drop trigger if exists on_auth_user_link_employee on auth.users;
create trigger on_auth_user_link_employee
  after insert on auth.users
  for each row execute procedure public.handle_new_user_link_employee();

-- 3. Retroactively link any EXISTING auth users to employee records
--    (fixes employees who already signed up but weren't linked)
update public.employees e
set user_id = u.id
from auth.users u
where lower(e.email) = lower(u.email)
  and e.user_id is null;

-- 4. Retroactively create missing profiles for existing auth users
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
