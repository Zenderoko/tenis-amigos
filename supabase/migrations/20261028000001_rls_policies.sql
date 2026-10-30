-- RLS policies
alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.matches enable row level security;
alter table public.match_participants enable row level security;
alter table public.match_proposals enable row level security;
alter table public.match_events enable row level security;

-- profiles
drop policy if exists "profiles_select_own_or_related" on public.profiles;
create policy "profiles_select_own_or_related" on public.profiles
  for select using (
    auth.uid() = id OR
    exists (select 1 from public.friendships f where f.status = 'accepted' and ((f.user_id = auth.uid() and f.friend_id = profiles.id) or (f.friend_id = auth.uid() and f.user_id = profiles.id))) OR
    exists (select 1 from public.match_participants mp join public.matches m on m.id = mp.match_id where mp.user_id = auth.uid() and exists (select 1 from public.match_participants mp2 where mp2.match_id = m.id and mp2.user_id = profiles.id))
  );

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- friendships
drop policy if exists "friendships_select_own" on public.friendships;
create policy "friendships_select_own" on public.friendships
  for select using (auth.uid() = user_id or auth.uid() = friend_id);

drop policy if exists "friendships_insert_own" on public.friendships;
create policy "friendships_insert_own" on public.friendships
  for insert with check (auth.uid() = user_id);

drop policy if exists "friendships_update_own" on public.friendships;
create policy "friendships_update_own" on public.friendships
  for update using (auth.uid() = user_id or auth.uid() = friend_id);

-- matches
drop policy if exists "matches_select_participant" on public.matches;
create policy "matches_select_participant" on public.matches
  for select using (
    organizer_id = auth.uid() OR
    exists (select 1 from public.match_participants mp where mp.match_id = matches.id and mp.user_id = auth.uid())
  );

drop policy if exists "matches_insert_organizer" on public.matches;
create policy "matches_insert_organizer" on public.matches
  for insert with check (organizer_id = auth.uid());

drop policy if exists "matches_update_organizer" on public.matches;
create policy "matches_update_organizer" on public.matches
  for update using (organizer_id = auth.uid());

-- match_participants
drop policy if exists "match_participants_select_participant" on public.match_participants;
create policy "match_participants_select_participant" on public.match_participants
  for select using (
    user_id = auth.uid() OR
    exists (select 1 from public.matches m where m.id = match_participants.match_id and m.organizer_id = auth.uid())
  );

drop policy if exists "match_participants_insert_organizer" on public.match_participants;
create policy "match_participants_insert_organizer" on public.match_participants
  for insert with check (
    exists (select 1 from public.matches m where m.id = match_id and m.organizer_id = auth.uid())
  );

drop policy if exists "match_participants_update_own_or_organizer" on public.match_participants;
create policy "match_participants_update_own_or_organizer" on public.match_participants
  for update using (
    user_id = auth.uid() OR
    exists (select 1 from public.matches m where m.id = match_participants.match_id and m.organizer_id = auth.uid())
  );

-- match_proposals
drop policy if exists "match_proposals_select_related" on public.match_proposals;
create policy "match_proposals_select_related" on public.match_proposals
  for select using (
    proposed_by = auth.uid() OR
    exists (select 1 from public.matches m where m.id = match_proposals.match_id and m.organizer_id = auth.uid()) OR
    exists (select 1 from public.match_participants mp where mp.match_id = match_proposals.match_id and mp.user_id = auth.uid())
  );

drop policy if exists "match_proposals_insert_related" on public.match_proposals;
create policy "match_proposals_insert_related" on public.match_proposals
  for insert with check (
    proposed_by = auth.uid() AND
    (exists (select 1 from public.matches m where m.id = match_id and m.organizer_id = auth.uid()) OR
     exists (select 1 from public.match_participants mp where mp.match_id = match_id and mp.user_id = auth.uid() and mp.response = 'accepted'))
  );

drop policy if exists "match_proposals_update_resolver" on public.match_proposals;
create policy "match_proposals_update_resolver" on public.match_proposals
  for update using (
    exists (select 1 from public.matches m where m.id = match_proposals.match_id and m.organizer_id = auth.uid())
  );

-- match_events
drop policy if exists "match_events_select_related" on public.match_events;
create policy "match_events_select_related" on public.match_events
  for select using (
    exists (select 1 from public.matches m where m.id = match_events.match_id and m.organizer_id = auth.uid()) OR
    exists (select 1 from public.match_participants mp where mp.match_id = match_events.match_id and mp.user_id = auth.uid())
  );

drop policy if exists "match_events_insert_related" on public.match_events;
create policy "match_events_insert_related" on public.match_events
  for insert with check (
    exists (select 1 from public.matches m where m.id = match_id and m.organizer_id = auth.uid()) OR
    exists (select 1 from public.match_participants mp where mp.match_id = match_id and mp.user_id = auth.uid())
  );
