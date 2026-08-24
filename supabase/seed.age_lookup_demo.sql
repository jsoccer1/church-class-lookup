-- Weekend preschool demonstration data. TEST DATA ONLY.
begin;
insert into public.rooms(name,description) values ('Room 110','Infant/toddler example room'),('Room 111','Young preschool example room'),('Room 112','Older preschool example room') on conflict(name) do nothing;
insert into public.services(name,start_time) values ('Saturday 5:00 PM','17:00'),('Sunday 8:30 AM','08:30'),('Sunday 9:45 AM','09:45'),('Sunday 11:00 AM','11:00'),('Sunday 12:15 PM','12:15') on conflict(name,start_time) do nothing;
insert into public.classes(name,description) values ('Infants (0–11 months)','Test age-band class'),('Young Toddlers (12–23 months)','Test age-band class'),('Older Toddlers (24–35 months)','Test age-band class'),('Preschool (36–47 months)','Test age-band class') on conflict(name) do nothing;
insert into public.teachers(first_name,last_name,active) select 'Jordan','Example',true where not exists(select 1 from public.teachers where first_name='Jordan' and last_name='Example');
insert into public.age_assignment_rules(class_id,minimum_months,maximum_months,effective_from,priority,active)
select c.id,v.min,v.max,'2020-01-01',1,true from (values ('Infants (0–11 months)',0,11),('Young Toddlers (12–23 months)',12,23),('Older Toddlers (24–35 months)',24,35),('Preschool (36–47 months)',36,47)) v(name,min,max) join public.classes c on c.name=v.name
on conflict(class_id,minimum_months,maximum_months,effective_from) do nothing;
insert into public.class_schedules(class_id,room_id,service_id,day_of_week,effective_from,active)
select c.id,r.id,s.id,0,'2020-01-01',true from public.classes c join public.rooms r on r.name=case c.name when 'Infants (0–11 months)' then 'Room 110' when 'Young Toddlers (12–23 months)' then 'Room 111' when 'Older Toddlers (24–35 months)' then 'Room 110' else 'Room 112' end cross join public.services s where c.name in ('Infants (0–11 months)','Young Toddlers (12–23 months)','Older Toddlers (24–35 months)','Preschool (36–47 months)') and s.name like 'Sunday%'
on conflict do nothing;
insert into public.class_teachers(class_id,teacher_id,effective_from,active) select c.id,t.id,'2020-01-01',true from public.classes c cross join public.teachers t where c.name like '%Toddlers%' and t.first_name='Jordan' and t.last_name='Example' on conflict do nothing;
insert into public.children(first_name,last_name,date_of_birth,guardian_name,guardian_email,notes,active) select 'Milo','Example','2023-10-27','Example Guardian','milo@example.invalid','Example child for age-in-months lookup.',true where not exists(select 1 from public.children where first_name='Milo' and last_name='Example' and date_of_birth='2023-10-27');
commit;
