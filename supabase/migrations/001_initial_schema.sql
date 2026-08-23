-- Church Children's Class Lookup: complete Supabase schema
create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'volunteer' check (role in ('admin','volunteer')),
  created_at timestamptz not null default now()
);
create table public.children (
  id uuid primary key default gen_random_uuid(),
  first_name text not null check (char_length(trim(first_name)) between 1 and 100),
  last_name text not null check (char_length(trim(last_name)) between 1 and 100),
  date_of_birth date not null check (date_of_birth <= current_date),
  guardian_name text, guardian_email text, notes text,
  active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.classes (
 id uuid primary key default gen_random_uuid(), name text not null unique, description text,
 active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.rooms (
 id uuid primary key default gen_random_uuid(), name text not null unique, description text, active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.services (
 id uuid primary key default gen_random_uuid(), name text not null, start_time time not null, active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(name,start_time)
);
create table public.teachers (
 id uuid primary key default gen_random_uuid(), first_name text not null, last_name text not null, active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.class_assignment_rules (
 id uuid primary key default gen_random_uuid(), class_id uuid not null references public.classes(id) on delete cascade,
 start_date date not null, end_date date not null, effective_from date not null default current_date, effective_until date,
 active boolean not null default true, priority integer not null default 100 check(priority >= 0),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check (start_date <= end_date), check (effective_until is null or effective_until >= effective_from)
);
create table public.class_schedules (
 id uuid primary key default gen_random_uuid(), class_id uuid not null references public.classes(id) on delete cascade,
 room_id uuid not null references public.rooms(id), service_id uuid not null references public.services(id),
 day_of_week smallint not null default 0 check(day_of_week between 0 and 6),
 effective_from date not null default current_date, effective_until date, active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(effective_until is null or effective_until >= effective_from)
);
create table public.class_teachers (
 id uuid primary key default gen_random_uuid(), class_id uuid not null references public.classes(id) on delete cascade,
 teacher_id uuid not null references public.teachers(id), effective_from date not null default current_date, effective_until date,
 active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(effective_until is null or effective_until >= effective_from)
);
create index children_name_idx on public.children(last_name,first_name) where active;
create index assignment_lookup_idx on public.class_assignment_rules(start_date,end_date,effective_from) where active;
create index schedule_lookup_idx on public.class_schedules(class_id,effective_from) where active;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from profiles where id=auth.uid() and role='admin') $$;
create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
create trigger children_updated before update on public.children for each row execute function public.set_updated_at();
create trigger classes_updated before update on public.classes for each row execute function public.set_updated_at();
create trigger rooms_updated before update on public.rooms for each row execute function public.set_updated_at();
create trigger services_updated before update on public.services for each row execute function public.set_updated_at();
create trigger teachers_updated before update on public.teachers for each row execute function public.set_updated_at();
create trigger rules_updated before update on public.class_assignment_rules for each row execute function public.set_updated_at();
create or replace function public.lookup_class(p_birth_date date, p_as_of date default current_date)
returns table(class_id uuid, class_name text, room_name text, service_name text, service_time time, teachers text[], conflict boolean)
language plpgsql security definer set search_path=public as $$
declare match_count integer;
begin
 if p_birth_date is null or p_birth_date > current_date then raise exception 'Invalid birth date'; end if;
 select count(*) into match_count from class_assignment_rules r join classes c on c.id=r.class_id and c.active
 where r.active and p_birth_date between r.start_date and r.end_date and p_as_of>=r.effective_from and (r.effective_until is null or p_as_of<=r.effective_until);
 if match_count=0 then return; end if;
 if match_count>1 and not exists(select 1 from class_assignment_rules r join classes c on c.id=r.class_id and c.active where r.active and p_birth_date between r.start_date and r.end_date and p_as_of>=r.effective_from and (r.effective_until is null or p_as_of<=r.effective_until) group by priority having count(*)=1) then
   return query select null::uuid,null::text,null::text,null::text,null::time,null::text[],true; return;
 end if;
 return query
 with picked as (select r.class_id from class_assignment_rules r join classes c on c.id=r.class_id and c.active where r.active and p_birth_date between r.start_date and r.end_date and p_as_of>=r.effective_from and (r.effective_until is null or p_as_of<=r.effective_until) order by r.priority asc limit 1)
 select c.id,c.name,rm.name,sv.name,sv.start_time,coalesce(array_agg(distinct concat(t.first_name,' ',t.last_name)) filter(where t.id is not null),array[]::text[]),false
 from picked p join classes c on c.id=p.class_id
 left join class_schedules cs on cs.class_id=c.id and cs.active and p_as_of>=cs.effective_from and (cs.effective_until is null or p_as_of<=cs.effective_until)
 left join rooms rm on rm.id=cs.room_id and rm.active left join services sv on sv.id=cs.service_id and sv.active
 left join class_teachers ct on ct.class_id=c.id and ct.active and p_as_of>=ct.effective_from and (ct.effective_until is null or p_as_of<=ct.effective_until)
 left join teachers t on t.id=ct.teacher_id and t.active group by c.id,c.name,rm.name,sv.name,sv.start_time;
end $$;
alter table public.profiles enable row level security; alter table public.children enable row level security; alter table public.classes enable row level security; alter table public.rooms enable row level security; alter table public.services enable row level security; alter table public.teachers enable row level security; alter table public.class_assignment_rules enable row level security; alter table public.class_schedules enable row level security; alter table public.class_teachers enable row level security;
create policy "admins manage profiles" on profiles for all using(is_admin()) with check(is_admin());
create policy "admins manage children" on children for all using(is_admin()) with check(is_admin());
create policy "admins manage classes" on classes for all using(is_admin()) with check(is_admin());
create policy "admins manage rooms" on rooms for all using(is_admin()) with check(is_admin());
create policy "admins manage services" on services for all using(is_admin()) with check(is_admin());
create policy "admins manage teachers" on teachers for all using(is_admin()) with check(is_admin());
create policy "admins manage rules" on class_assignment_rules for all using(is_admin()) with check(is_admin());
create policy "admins manage schedules" on class_schedules for all using(is_admin()) with check(is_admin());
create policy "admins manage class teachers" on class_teachers for all using(is_admin()) with check(is_admin());
grant execute on function public.lookup_class(date,date) to anon,authenticated;
-- First admin: create an Auth user in Supabase, then run:
-- insert into public.profiles(id,role) values ('AUTH_USER_UUID','admin');
