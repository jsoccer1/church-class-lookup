-- TEST DATA ONLY — creates a single class that matches all current and future test children.
-- Run after 001_initial_schema.sql and 002_add_child_name_search.sql.
begin;

insert into public.classes (name, description, active)
select 'Test Children Class', 'Test-only class for verifying the lookup workflow.', true
where not exists (select 1 from public.classes where name = 'Test Children Class');

insert into public.rooms (name, description, active)
select 'Test Room', 'Test-only room.', true
where not exists (select 1 from public.rooms where name = 'Test Room');

insert into public.services (name, start_time, active)
select 'Test Service', '09:00'::time, true
where not exists (select 1 from public.services where name = 'Test Service' and start_time = '09:00'::time);

insert into public.teachers (first_name, last_name, active)
select 'Taylor', 'Test', true
where not exists (
  select 1 from public.teachers where first_name = 'Taylor' and last_name = 'Test'
);

insert into public.class_assignment_rules (class_id, start_date, end_date, effective_from, active, priority)
select c.id, '1900-01-01'::date, '2100-12-31'::date, '2000-01-01'::date, true, 0
from public.classes c
where c.name = 'Test Children Class'
and not exists (
  select 1 from public.class_assignment_rules r
  where r.class_id = c.id
    and r.start_date = '1900-01-01'::date
    and r.end_date = '2100-12-31'::date
    and r.effective_from = '2000-01-01'::date
);

insert into public.class_schedules (class_id, room_id, service_id, day_of_week, effective_from, active)
select c.id, r.id, s.id, 0, '2000-01-01'::date, true
from public.classes c
cross join public.rooms r
cross join public.services s
where c.name = 'Test Children Class'
  and r.name = 'Test Room'
  and s.name = 'Test Service'
  and s.start_time = '09:00'::time
  and not exists (
    select 1 from public.class_schedules cs
    where cs.class_id = c.id and cs.room_id = r.id and cs.service_id = s.id
      and cs.day_of_week = 0 and cs.effective_from = '2000-01-01'::date
  );

insert into public.class_teachers (class_id, teacher_id, effective_from, active)
select c.id, t.id, '2000-01-01'::date, true
from public.classes c
cross join public.teachers t
where c.name = 'Test Children Class'
  and t.first_name = 'Taylor' and t.last_name = 'Test'
  and not exists (
    select 1 from public.class_teachers ct
    where ct.class_id = c.id and ct.teacher_id = t.id and ct.effective_from = '2000-01-01'::date
  );

commit;
