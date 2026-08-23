# Children's Class Lookup

A mobile-first, GitHub Pages–deployable church class lookup built with React/Vite and Supabase. The volunteer workflow is intentionally short: enter a birthday, then see the configured class, room, service, and teachers.

## Project structure
- `src/` — React app, public lookup, sign-in, and protected admin dashboard
- `supabase/migrations/001_initial_schema.sql` — complete tables, constraints, indexes, RLS, roles, and lookup RPC
- `supabase/seed.example.sql` — clearly labeled example data
- `.env.example` — required client-side environment variable names
- `.github/workflows/deploy-pages.yml` — automatic GitHub Pages deployment

## Local setup
1. Create a Supabase project.
2. In the Supabase SQL Editor, run `supabase/migrations/001_initial_schema.sql`, then optionally `supabase/seed.example.sql`.
3. Create the first administrator in Supabase Authentication (email/password), then run:
   ```sql
   insert into public.profiles(id, role) values ('AUTH_USER_UUID', 'admin');
   ```
4. Copy `.env.example` to `.env.local`, and add the project URL and **anon** key. Never put the service-role key in the browser.
5. Run `npm install` and `npm run dev`.

## Deploy to GitHub Pages
1. In GitHub, open **Settings → Pages** and choose **GitHub Actions** as the source.
2. Push to `main`. The included workflow builds and deploys the site automatically.
3. Open `https://jsoccer1.github.io/church-class-lookup/` when the action finishes.
4. GitHub Pages serves static files, so routes use hashes: `/#/login` and `/#/admin`.

## Security and privacy
The public page calls only the `lookup_class` database function and never reads the children table. Child records, notes, and guardian fields are protected by Row Level Security; only users explicitly designated `admin` may manage them. The app does not store child data in browser storage.

## Administration
Sign in at `/#/login`. The dashboard manages children, classes, rooms, services, teachers, date-range assignment rules, schedules, and teacher assignments. Rules use inclusive birthday endpoints and effective dates, allowing a future school year to be configured without overwriting history. The priority field resolves overlapping rules; equal unresolved matches return an administrator warning instead of an incorrect result.

## Replace before launch
The seed rows, names, rooms, teachers, dates, and service times are examples only. Replace them with the church’s actual information. For production, also enable the appropriate Supabase Auth email settings and restrict allowed redirect URLs to the deployed domain.

## Verification checklist
- Test the first and last birthday in every rule, plus one day outside each boundary.
- Test blank, malformed, future, and February 29 birthdays.
- Verify anonymous users cannot select or modify child data.
- Verify a non-admin signed-in user is blocked from the dashboard.
- Verify an admin can add/edit/deactivate every entity.
- Test narrow phone, tablet, and desktop widths.
