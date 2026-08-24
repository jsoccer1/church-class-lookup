-- Classroom presentation/capacity and public age-in-months lookup.
alter table public.classes add column if not exists color text not null default '#2f6b5f' check(color ~ '^#[0-9A-Fa-f]{6}$');
alter table public.classes add column if not exists capacity smallint not null default 12 check(capacity between 1 and 50);

create or replace function public.lookup_class_by_age_months(p_age_months integer,p_as_of date default current_date)
returns table(class_id uuid,class_name text,room_name text,service_name text,service_time time,conflict boolean)
language plpgsql security definer set search_path=public as $$
declare matches integer;
begin
 if p_age_months is null or p_age_months<0 or p_age_months>240 then raise exception 'Invalid age in months'; end if;
 select count(*) into matches from age_assignment_rules r join classes c on c.id=r.class_id and c.active
 where r.active and p_age_months between r.minimum_months and r.maximum_months and p_as_of>=r.effective_from and (r.effective_until is null or p_as_of<=r.effective_until);
 if matches=0 then return; end if;
 if (select count(*) from age_assignment_rules r join classes c on c.id=r.class_id and c.active where r.active and p_age_months between r.minimum_months and r.maximum_months and p_as_of>=r.effective_from and (r.effective_until is null or p_as_of<=r.effective_until) and r.priority=(select min(priority) from age_assignment_rules where active and p_age_months between minimum_months and maximum_months and p_as_of>=effective_from and (effective_until is null or p_as_of<=effective_until)))>1 then return query select null::uuid,null::text,null::text,null::text,null::time,true; return; end if;
 return query with picked as (select r.class_id from age_assignment_rules r join classes c on c.id=r.class_id and c.active where r.active and p_age_months between r.minimum_months and r.maximum_months and p_as_of>=r.effective_from and (r.effective_until is null or p_as_of<=r.effective_until) order by priority limit 1)
 select c.id,c.name,rm.name,s.name,s.start_time,false from picked p join classes c on c.id=p.class_id left join class_schedules cs on cs.class_id=c.id and cs.active and p_as_of>=cs.effective_from and (cs.effective_until is null or p_as_of<=cs.effective_until) left join rooms rm on rm.id=cs.room_id and rm.active left join services s on s.id=cs.service_id and s.active limit 1;
end $$;
grant execute on function public.lookup_class_by_age_months(integer,date) to anon,authenticated;
