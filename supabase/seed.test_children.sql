-- TEST DATA ONLY — fictional children. Safe to remove before production.
-- Run this in Supabase SQL Editor after the schema migration.
insert into public.children (first_name, last_name, date_of_birth, guardian_name, guardian_email, notes, active)
select * from (values
  ('Mido',  'Test', '2022-03-14'::date, 'Test Guardian', 'mido.test@example.invalid',  'Test record — no real child information.', true),
  ('Maple', 'Test', '2022-08-31'::date, 'Test Guardian', 'maple.test@example.invalid', 'Tests an end-of-range birthday.', true),
  ('John',  'Test', '2021-09-01'::date, 'Test Guardian', 'john.test@example.invalid',  'Tests a start-of-range birthday.', true),
  ('Ally',  'Test', '2024-02-29'::date, 'Test Guardian', 'ally.test@example.invalid',  'Tests a leap-day birthday.', true),
  ('Bob',   'Test', '2023-12-15'::date, 'Test Guardian', 'bob.test@example.invalid',   'Test record — no real child information.', true)
) as test_children(first_name,last_name,date_of_birth,guardian_name,guardian_email,notes,active)
where not exists (
  select 1 from public.children c
  where c.first_name = test_children.first_name
    and c.last_name = test_children.last_name
    and c.date_of_birth = test_children.date_of_birth
);
