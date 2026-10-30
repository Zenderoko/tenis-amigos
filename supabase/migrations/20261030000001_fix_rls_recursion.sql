-- Corrige la recursión infinita entre las políticas de match_participants,
-- matches y profiles. Las funciones SECURITY DEFINER consultan las tablas sin
-- volver a aplicar RLS, y las políticas solo usan esas funciones.

create or replace function public.is_match_participant(
  p_match_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.match_participants mp
    where mp.match_id = p_match_id
      and mp.user_id = p_user_id
  );
$$;

create or replace function public.is_match_organizer(
  p_match_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.matches m
    where m.id = p_match_id
      and m.organizer_id = p_user_id
  );
$$;

create or replace function public.are_friends(
  p_user_a uuid,
  p_user_b uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.friendships f
    where f.status = 'accepted'
      and (
        (f.user_id = p_user_a and f.friend_id = p_user_b)
        or (f.friend_id = p_user_a and f.user_id = p_user_b)
      )
  );
$$;

create or replace function public.share_match(
  p_user_a uuid,
  p_user_b uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.match_participants mp1
    join public.match_participants mp2 on mp2.match_id = mp1.match_id
    where mp1.user_id = p_user_a
      and mp2.user_id = p_user_b
  );
$$;

create or replace function public.is_accepted_participant(
  p_match_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.match_participants mp
    where mp.match_id = p_match_id
      and mp.user_id = p_user_id
      and mp.response = 'accepted'
  );
$$;

-- profiles
drop policy if exists "profiles_select_own_or_related" on public.profiles;
create policy "profiles_select_own_or_related" on public.profiles
  for select using (
    auth.uid() = id
    or public.are_friends(auth.uid(), id)
    or public.share_match(auth.uid(), id)
  );

-- matches
drop policy if exists "matches_select_participant" on public.matches;
create policy "matches_select_participant" on public.matches
  for select using (
    organizer_id = auth.uid()
    or public.is_match_participant(id, auth.uid())
  );

-- match_participants
drop policy if exists "match_participants_select_participant" on public.match_participants;
create policy "match_participants_select_participant" on public.match_participants
  for select using (
    user_id = auth.uid()
    or public.is_match_organizer(match_id, auth.uid())
  );

drop policy if exists "match_participants_insert_organizer" on public.match_participants;
create policy "match_participants_insert_organizer" on public.match_participants
  for insert with check (
    public.is_match_organizer(match_id, auth.uid())
  );

drop policy if exists "match_participants_update_own_or_organizer" on public.match_participants;
create policy "match_participants_update_own_or_organizer" on public.match_participants
  for update using (
    user_id = auth.uid()
    or public.is_match_organizer(match_id, auth.uid())
  );

-- match_proposals
drop policy if exists "match_proposals_select_related" on public.match_proposals;
create policy "match_proposals_select_related" on public.match_proposals
  for select using (
    proposed_by = auth.uid()
    or public.is_match_organizer(match_id, auth.uid())
    or public.is_match_participant(match_id, auth.uid())
  );

drop policy if exists "match_proposals_insert_related" on public.match_proposals;
create policy "match_proposals_insert_related" on public.match_proposals
  for insert with check (
    proposed_by = auth.uid()
    and (
      public.is_match_organizer(match_id, auth.uid())
      or public.is_accepted_participant(match_id, auth.uid())
    )
  );

drop policy if exists "match_proposals_update_resolver" on public.match_proposals;
create policy "match_proposals_update_resolver" on public.match_proposals
  for update using (
    public.is_match_organizer(match_id, auth.uid())
  );

-- match_events
drop policy if exists "match_events_select_related" on public.match_events;
create policy "match_events_select_related" on public.match_events
  for select using (
    public.is_match_organizer(match_id, auth.uid())
    or public.is_match_participant(match_id, auth.uid())
  );

drop policy if exists "match_events_insert_related" on public.match_events;
create policy "match_events_insert_related" on public.match_events
  for insert with check (
    public.is_match_organizer(match_id, auth.uid())
    or public.is_match_participant(match_id, auth.uid())
  );
