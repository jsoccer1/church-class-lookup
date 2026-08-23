-- Public lookup returns only the minimum identity information needed to choose a child.
-- The children table remains protected by RLS; this is the only anonymous name-search surface.
create or replace function public.search_children(p_query text)
returns table(child_id uuid, first_name text, last_name text, date_of_birth date)
language sql
security definer
set search_path=public
as $$
  select c.id, c.first_name, c.last_name, c.date_of_birth
  from public.children c
  where c.active
    and length(trim(p_query)) >= 2
    and (
      c.first_name ilike trim(p_query) || '%'
      or c.last_name ilike trim(p_query) || '%'
    )
  order by c.last_name, c.first_name, c.date_of_birth
  limit 10;
$$;

grant execute on function public.search_children(text) to anon, authenticated;
