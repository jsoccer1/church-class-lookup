-- Example data only. Replace these with your church's actual classes and ranges.
insert into public.classes(name,description) values ('Nursery','Example: infants'),('1-Year-Olds','Example class'),('2-Year-Olds','Example class'),('3-Year-Olds','Example class'),('4-Year-Olds','Example class'),('Pre-K','Example class');
insert into public.rooms(name) values ('Room 101'),('Room 102'),('Room 103'),('Room 104');
insert into public.services(name,start_time) values ('Sunday 9:00 AM','09:00'),('Sunday 10:45 AM','10:45');
insert into public.teachers(first_name,last_name) values ('Jane','Smith'),('Alex','Johnson');
-- Sample 2026–27 school-year rules. Dates are inclusive.
insert into public.class_assignment_rules(class_id,start_date,end_date,effective_from,priority)
select id,'2022-09-01','2023-08-31','2026-09-01',1 from public.classes where name='3-Year-Olds';
insert into public.class_schedules(class_id,room_id,service_id,day_of_week,effective_from)
select c.id,r.id,s.id,0,'2026-09-01' from public.classes c,public.rooms r,public.services s where c.name='3-Year-Olds' and r.name='Room 104' and s.start_time='09:00';
insert into public.class_teachers(class_id,teacher_id,effective_from)
select c.id,t.id,'2026-09-01' from public.classes c,public.teachers t where c.name='3-Year-Olds' and t.first_name='Jane' and t.last_name='Smith';
