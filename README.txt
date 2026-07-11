-- REACH UNIVERSE: secure membership, directory, wall, chat, and media foundation
-- Run this once inside the SQL Editor of a dedicated Supabase project.
create extension if not exists "pgcrypto";

create table if not exists public.reach_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'REACH Member',
  school text,
  major text,
  graduation_year text,
  role text not null default 'student' check (role in ('student','ambassador','lead_ambassador','chapter_board','advisor','regional','national')),
  bio text,
  interests text[] not null default '{}',
  avatar_url text,
  directory_opt_in boolean not null default false,
  approved boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Members control their own biography and visibility, but cannot self-assign an Ambassador/staff role.
create or replace function public.reach_protect_profile_privileges()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.role := 'student';
    new.approved := true;
  elsif tg_op = 'UPDATE' then
    new.role := old.role;
    new.approved := old.approved;
  end if;
  return new;
end;
$$;
drop trigger if exists reach_profile_privilege_guard on public.reach_profiles;
create trigger reach_profile_privilege_guard before insert or update on public.reach_profiles
for each row execute function public.reach_protect_profile_privileges();

create table if not exists public.reach_wall_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.reach_profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1400),
  campus text,
  topic text not null default 'encouragement',
  visibility text not null default 'community' check (visibility in ('community','campus')),
  moderation_status text not null default 'published' check (moderation_status in ('pending','published','hidden')),
  created_at timestamptz not null default now()
);

create table if not exists public.reach_chat_messages (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.reach_profiles(id) on delete cascade,
  room text not null default 'national',
  body text not null check (char_length(body) between 1 and 800),
  created_at timestamptz not null default now()
);

create table if not exists public.reach_media (
  id uuid primary key default gen_random_uuid(),
  uploader_id uuid not null references public.reach_profiles(id) on delete cascade,
  storage_path text not null,
  caption text,
  campus text,
  event_name text,
  consent_confirmed boolean not null default false,
  moderation_status text not null default 'pending' check (moderation_status in ('pending','approved','hidden')),
  created_at timestamptz not null default now()
);

create table if not exists public.reach_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references auth.users(id) on delete set null,
  target_type text not null,
  target_id uuid,
  reason text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.reach_box_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.reach_profiles(id) on delete cascade,
  school text not null,
  state text,
  student_status text,
  needs text[] not null default '{}',
  note text,
  status text not null default 'submitted' check (status in ('submitted','under_review','approved','not_approved','fulfilled')),
  created_at timestamptz not null default now()
);

create table if not exists public.reach_ambassador_applications (
  id uuid primary key default gen_random_uuid(),
  applicant_id uuid not null references public.reach_profiles(id) on delete cascade,
  school text not null,
  state text,
  graduation_year text,
  why_reach text not null,
  availability text,
  status text not null default 'submitted' check (status in ('submitted','under_review','interview','approved','training','certified')),
  created_at timestamptz not null default now()
);

alter table public.reach_profiles enable row level security;
alter table public.reach_wall_posts enable row level security;
alter table public.reach_chat_messages enable row level security;
alter table public.reach_media enable row level security;
alter table public.reach_reports enable row level security;
alter table public.reach_box_requests enable row level security;
alter table public.reach_ambassador_applications enable row level security;

drop policy if exists "reach profiles visible when opted in" on public.reach_profiles;
create policy "reach profiles visible when opted in" on public.reach_profiles for select using (directory_opt_in = true and approved = true or auth.uid() = id);
drop policy if exists "reach members manage own profile" on public.reach_profiles;
create policy "reach members manage own profile" on public.reach_profiles for all using (auth.uid() = id) with check (auth.uid() = id);
drop policy if exists "reach wall visible to members" on public.reach_wall_posts;
create policy "reach wall visible to members" on public.reach_wall_posts for select to authenticated using (moderation_status = 'published' or author_id = auth.uid());
drop policy if exists "reach members create own wall posts" on public.reach_wall_posts;
create policy "reach members create own wall posts" on public.reach_wall_posts for insert to authenticated with check (auth.uid() = author_id);
drop policy if exists "reach chats visible to members" on public.reach_chat_messages;
create policy "reach chats visible to members" on public.reach_chat_messages for select to authenticated using (true);
drop policy if exists "reach members create chat messages" on public.reach_chat_messages;
create policy "reach members create chat messages" on public.reach_chat_messages for insert to authenticated with check (auth.uid() = author_id);
drop policy if exists "reach media own or approved" on public.reach_media;
create policy "reach media own or approved" on public.reach_media for select to authenticated using (moderation_status = 'approved' or uploader_id = auth.uid());
drop policy if exists "reach members upload own media records" on public.reach_media;
create policy "reach members upload own media records" on public.reach_media for insert to authenticated with check (auth.uid() = uploader_id);
drop policy if exists "reach members report safely" on public.reach_reports;
create policy "reach members report safely" on public.reach_reports for insert to authenticated with check (auth.uid() = reporter_id);
drop policy if exists "reach members create their own box request" on public.reach_box_requests;
create policy "reach members create their own box request" on public.reach_box_requests for insert to authenticated with check (auth.uid() = requester_id);
drop policy if exists "reach members view own box request" on public.reach_box_requests;
create policy "reach members view own box request" on public.reach_box_requests for select to authenticated using (auth.uid() = requester_id);
drop policy if exists "reach members create ambassador application" on public.reach_ambassador_applications;
create policy "reach members create ambassador application" on public.reach_ambassador_applications for insert to authenticated with check (auth.uid() = applicant_id);
drop policy if exists "reach members view own ambassador application" on public.reach_ambassador_applications;
create policy "reach members view own ambassador application" on public.reach_ambassador_applications for select to authenticated using (auth.uid() = applicant_id);

-- Create a private bucket in Storage named reach-media in the Supabase dashboard.
-- Do NOT make the bucket public. Staff should review consent and approve media before it appears in community areas.
