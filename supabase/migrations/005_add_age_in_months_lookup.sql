-- Age-in-months assignment rules and time-specific lookup.
create table if not exists public.age_assignment_rules (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  minimum_months integer not null check(minimum_months >= 0),
  maximum_months integer not null check(maximum_months >= minimum_months),
  effective_from date not null default current_date,
  effective_until date,
  priority integer not null default 100 check(priority >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(effective_until is null or effective_until >= effective_from)
);
create unique index if not exists age_rules_unique on public.age_assignment_rules(class_id,minimum_months,maximum_months,effective_from);
create trigger age_rules_updated before update on public.age_assignment_rules for each row execute function public.set_updated_at();
alter table public.age_assignment_rules enable row level security;
create policy "admins manage age rules" on public.age_assignment_rules for all using(public.is_admin()) with check(public.is_admin());

create or replace function public.lookup_services(p_day_of_week smallint default 0, p_as_of date default current_date)
returns table(service_id uuid, service_name text, start_time time)
language sql security definer set search_path=public as $$
  select distinct s.id,s.name,s.start_time
  from services s join class_schedules cs on cs.service_id=s.id
  where s.active and cs.active and cs.day_of_week=p_day_of_week
    and p_as_of>=cs.effective_from and (cs.effective_until is null or p_as_of<=cs.effective_until)
  order by s.start_time;
$$;

create or replace function public.lookup_class_for_time(p_birth_date date,p_service_id uuid,p_day_of_week smallint default 0,p_as_of date default current_date)
returns table(class_id uuid,class_name text,room_name text,service_name text,service_time time,teachers text[],age_months integer,conflict boolean)
language plpgsql security definer set search_path=public as $$
declare months_old integer; matches integer;
begin
  if p_birth_date is null or p_birth_date>p_as_of then raise exception 'Invalid birth date'; end if;
  months_old := extract(year from age(p_as_of,p_birth_date))*12 + extract(month from age(p_as_of,p_birth_date));
  select count(*) into matches from age_assignment_rules r join classes c on c.id=r.class_id and c.active
  join class_schedules cs on cs.class_id=c.id and cs.service_id=p_service_id and cs.day_of_week=p_day_of_week and cs.active
  where r.active and months_old between r.minimum_months and r.maximum_months and p_as_of>=r.effective_from and (r.effective_until is null or p_as_of<=r.effective_until)
    and p_as_of>=cs.effective_from and (cs.effective_until is null or p_as_of<=cs.effective_until);
  if matches=0 then return; end if;
  if (select count(*) from age_assignment_rules r join classes c on c.id=r.class_id and c.active join class_schedules cs on cs.class_id=c.id and cs.service_id=p_service_id and cs.day_of_week=p_day_of_week and cs.active where r.active and months_old between r.minimum_months and r.maximum_months and p_as_of>=r.effective_from and (r.effective_until is null or p_as_of<=r.effective_until) and p_as_of>=cs.effective_from and (cs.effective_until is null or p_as_of<=cs.effective_until) and r.priority=(select min(r2.priority) from age_assignment_rules r2 join classes c2 on c2.id=r2.class_id and c2.active join class_schedules cs2 on cs2.class_id=c2.id and cs2.service_id=p_service_id and cs2.day_of_week=p_day_of_week and cs2.active where r2.active and months_old between r2.minimum_months and r2.maximum_months and p_as_of>=r2.effective_from and (r2.effective_until is null or p_as_of<=r2.effective_until) and p_as_of>=cs2.effective_from and (cs2.effective_until is null or p_as_of<=cs2.effective_until))) > 1 then
    return query select null::uuid,null::text,null::text,null::text,null::time,null::text[],months_old,true; return;
  end if;
  return query with picked as (select r.class_id from age_assignment_rules r join classes c on c.id=r.class_id and c.active join class_schedules cs on cs.class_id=c.id and cs.service_id=p_service_id and cs.day_of_week=p_day_of_week and cs.active where r.active and months_old between r.minimum_months and r.maximum_months and p_as_of>=r.effective_from and (r.effective_until is null or p_as_of<=r.effective_until) and p_as_of>=cs.effective_from and (cs.effective_until is null or p_as_of<=cs.effective_until) order by r.priority limit 1)
  select c.id,c.name,rm.name,s.name,s.start_time,coalesce(array_agg(distinct concat(t.first_name,' ',t.last_name)) filter(where t.id is not null),array[]::text[]),months_old,false from picked p join classes c on c.id=p.class_id join class_schedules cs on cs.class_id=c.id and cs.service_id=p_service_id and cs.day_of_week=p_day_of_week and cs.active join rooms rm on rm.id=cs.room_id and rm.active join services s on s.id=cs.service_id and s.active left join class_teachers ct on ct.class_id=c.id and ct.active and p_as_of>=ct.effective_from and (ct.effective_until is null or p_as_of<=ct.effective_until) left join teachers t on t.id=ct.teacher_id and t.active group by c.id,c.name,rm.name,s.name,s.start_time;
end $$;
grant execute on function public.lookup_services(smallint,date),public.lookup_class_for_time(date,uuid,smallint,date) to anon,authenticated;
