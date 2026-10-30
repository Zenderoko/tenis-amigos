-- Migración inicial: esquema base para TenisAmigos
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  avatar_url text,
  tennis_level text,
  dominant_hand text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  friend_id uuid not null references public.profiles(id) on delete cascade,
  status text not null check (status in ('pending','accepted','rejected')),
  created_at timestamptz not null default now(),
  unique(user_id, friend_id)
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references public.profiles(id) on delete cascade,
  format text not null check (format in ('singles','doubles')),
  starts_at timestamptz not null,
  timezone text,
  duration_minutes int not null check (duration_minutes > 0),
  location_name text not null,
  location_details text,
  status text not null check (status in ('awaiting_players','confirmed','cancelled','completed')),
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.match_participants (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('organizer','player')),
  response text not null check (response in ('invited','accepted','declined','withdrawn')),
  invited_at timestamptz not null default now(),
  responded_at timestamptz,
  unique(match_id, user_id)
);

create table if not exists public.match_proposals (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  proposed_by uuid not null references public.profiles(id) on delete cascade,
  proposed_starts_at timestamptz not null,
  proposed_timezone text,
  status text not null check (status in ('pending','accepted','rejected','superseded')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.match_events (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  type text not null check (type in ('created','invited','responded','proposed','rescheduled','cancelled','completed')),
  description text not null,
  created_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute procedure public.set_updated_at();

drop trigger if exists set_matches_updated_at on public.matches;
create trigger set_matches_updated_at
  before update on public.matches
  for each row execute procedure public.set_updated_at();
