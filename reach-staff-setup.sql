-- REACH STAFF COMMAND CENTER: run after reach-supabase.sql
create table if not exists public.reach_staff_emails (
  email text primary key,
  created_at timestamptz not null default now()
);
alter table public.reach_staff_emails enable row level security;
insert into public.reach_staff_emails (email) values
  ('shaynavincent24@outlook.com'),
  ('reach@estherfundsinc.org')
on conflict (email) do nothing;

create or replace function public.reach_is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.reach_staff_emails
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email',''))
  );
$$;
revoke all on function public.reach_is_staff() from public;
grant execute on function public.reach_is_staff() to authenticated;

drop policy if exists "reach staff view all profiles" on public.reach_profiles;
create policy "reach staff view all profiles" on public.reach_profiles for select to authenticated using (public.reach_is_staff());
drop policy if exists "reach staff view all media" on public.reach_media;
create policy "reach staff view all media" on public.reach_media for select to authenticated using (public.reach_is_staff());
drop policy if exists "reach staff update media review" on public.reach_media;
create policy "reach staff update media review" on public.reach_media for update to authenticated using (public.reach_is_staff()) with check (public.reach_is_staff());
drop policy if exists "reach staff view all boxes" on public.reach_box_requests;
create policy "reach staff view all boxes" on public.reach_box_requests for select to authenticated using (public.reach_is_staff());
drop policy if exists "reach staff update boxes" on public.reach_box_requests;
create policy "reach staff update boxes" on public.reach_box_requests for update to authenticated using (public.reach_is_staff()) with check (public.reach_is_staff());
drop policy if exists "reach staff view all ambassador applications" on public.reach_ambassador_applications;
create policy "reach staff view all ambassador applications" on public.reach_ambassador_applications for select to authenticated using (public.reach_is_staff());
drop policy if exists "reach staff update ambassador applications" on public.reach_ambassador_applications;
create policy "reach staff update ambassador applications" on public.reach_ambassador_applications for update to authenticated using (public.reach_is_staff()) with check (public.reach_is_staff());
drop policy if exists "reach staff view all wall posts" on public.reach_wall_posts;
create policy "reach staff view all wall posts" on public.reach_wall_posts for select to authenticated using (public.reach_is_staff());
drop policy if exists "reach staff moderate wall posts" on public.reach_wall_posts;
create policy "reach staff moderate wall posts" on public.reach_wall_posts for update to authenticated using (public.reach_is_staff()) with check (public.reach_is_staff());
drop policy if exists "reach staff view uploaded files" on storage.objects;
create policy "reach staff view uploaded files" on storage.objects for select to authenticated using (bucket_id = 'reach-media' and public.reach_is_staff());
