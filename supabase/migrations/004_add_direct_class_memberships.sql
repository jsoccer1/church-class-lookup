-- Adds administrator-managed direct class memberships for exceptional/manual placements.
create table if not exists public.child_class_assignments (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  effective_from date not null default current_date,
  effective_until date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_until is null or effective_until >= effective_from)
);
create unique index if not exists child_class_assignments_active_unique
  on public.child_class_assignments(child_id) where active;
create trigger child_class_assignments_updated before update on public.child_class_assignments
  for each row execute function public.set_updated_at();

alter table public.child_class_assignments enable row level security;
create policy "admins manage child class assignments"
  on public.child_class_assignments for all using(public.is_admin()) with check(public.is_admin());

create or replace function public.lookup_child_class(p_child_id uuid, p_as_of date default current_date)
returns table(class_id uuid, class_name text, room_name text, service_name text, service_time time, teachers text[], conflict boolean)
language plpgsql security definer set search_path=public as $$
declare chosen_class uuid; birth_date date;
begin
  select a.class_id into chosen_class
  from child_class_assignments a join classes c on c.id=a.class_id and c.active
  where a.child_id=p_child_id and a.active
    and p_as_of>=a.effective_from and (a.effective_until is null or p_as_of<=a.effective_until)
  order by a.effective_from desc limit 1;
  if chosen_class is not null then
    return query
    select c.id,c.name,rm.name,sv.name,sv.start_time,
      coalesce(array_agg(distinct concat(t.first_name,' ',t.last_name)) filter(where t.id is not null),array[]::text[]),false
    from classes c
    left join class_schedules cs on cs.class_id=c.id and cs.active and p_as_of>=cs.effective_from and (cs.effective_until is null or p_as_of<=cs.effective_until)
    left join rooms rm on rm.id=cs.room_id and rm.active
    left join services sv on sv.id=cs.service_id and sv.active
    left join class_teachers ct on ct.class_id=c.id and ct.active and p_as_of>=ct.effective_from and (ct.effective_until is null or p_as_of<=ct.effective_until)
    left join teachers t on t.id=ct.teacher_id and t.active
    where c.id=chosen_class group by c.id,c.name,rm.name,sv.name,sv.start_time;
    return;
  end if;
  select date_of_birth into birth_date from children where id=p_child_id and active;
  if birth_date is not null then return query select * from lookup_class(birth_date,p_as_of); end if;
end $$;
grant execute on function public.lookup_child_class(uuid,date) to anon, authenticated;
