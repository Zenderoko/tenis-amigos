-- Partidos de la Etapa 4: creación, invitaciones y respuestas controladas por
-- RPC. El cliente no escribe directamente en las tablas de partidos.

-- 1) Integridad e índices.
alter table public.matches
  alter column timezone set default 'America/Santiago';

alter table public.matches
  drop constraint if exists matches_duration_allowed;
alter table public.matches
  add constraint matches_duration_allowed
  check (duration_minutes in (60, 75, 90, 120));

alter table public.matches
  drop constraint if exists matches_location_name_not_blank;
alter table public.matches
  add constraint matches_location_name_not_blank
  check (btrim(location_name) <> '');

create index if not exists matches_starts_at_idx
  on public.matches (starts_at);
create index if not exists matches_organizer_id_idx
  on public.matches (organizer_id);
create index if not exists match_participants_match_id_idx
  on public.match_participants (match_id);
create index if not exists match_participants_user_id_idx
  on public.match_participants (user_id);
create index if not exists match_events_match_id_idx
  on public.match_events (match_id, created_at);

-- 2) RLS: cualquier participante puede ver a todos los jugadores del partido.
drop policy if exists "match_participants_select_participant"
  on public.match_participants;
create policy "match_participants_select_participant"
  on public.match_participants
  for select to authenticated
  using (
    public.is_match_participant(match_id, auth.uid())
    or public.is_match_organizer(match_id, auth.uid())
  );

-- Las mutaciones pasan por RPC SECURITY DEFINER. Se eliminan las políticas de
-- escritura directa y se revocan los privilegios para evitar que el cliente
-- salte las reglas de negocio.
drop policy if exists "matches_insert_organizer" on public.matches;
drop policy if exists "matches_update_organizer" on public.matches;
drop policy if exists "match_participants_insert_organizer"
  on public.match_participants;
drop policy if exists "match_participants_update_own_or_organizer"
  on public.match_participants;
drop policy if exists "match_events_insert_related" on public.match_events;

revoke insert, update, delete on public.matches from anon, authenticated;
revoke insert, update, delete on public.match_participants from anon, authenticated;
revoke insert, update, delete on public.match_events from anon, authenticated;

-- 3) Crear un partido y sus invitaciones en una sola transacción.
create or replace function public.create_match(
  p_format text,
  p_starts_at timestamptz,
  p_timezone text,
  p_duration_minutes int,
  p_location_name text,
  p_location_details text,
  p_invitee_ids uuid[]
)
returns table (created_match_id uuid, created_status text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_match_id uuid;
  v_max_players int;
  v_timezone text := coalesce(nullif(btrim(p_timezone), ''), 'America/Santiago');
  v_name text;
  v_invitee uuid;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  v_max_players := case p_format
    when 'singles' then 2
    when 'doubles' then 4
    else null
  end;
  if v_max_players is null then
    raise exception 'invalid_format' using errcode = '22023';
  end if;

  if p_starts_at is null or p_starts_at <= now() then
    raise exception 'invalid_start_time' using errcode = '22023';
  end if;
  if not exists (select 1 from pg_timezone_names where name = v_timezone) then
    raise exception 'invalid_timezone' using errcode = '22023';
  end if;
  if p_duration_minutes is null
     or p_duration_minutes not in (60, 75, 90, 120) then
    raise exception 'invalid_duration' using errcode = '22023';
  end if;
  if p_location_name is null or btrim(p_location_name) = '' then
    raise exception 'invalid_location' using errcode = '22023';
  end if;

  if p_invitee_ids is null
     or cardinality(p_invitee_ids) < 1
     or cardinality(p_invitee_ids) > v_max_players - 1 then
    raise exception 'invitees_required' using errcode = '22023';
  end if;
  if exists (
    select 1 from unnest(p_invitee_ids) as invitee(id)
    where invitee.id is null
  ) then
    raise exception 'invalid_invitee' using errcode = '22023';
  end if;
  if (
    select count(distinct invitee.id)
    from unnest(p_invitee_ids) as invitee(id)
  ) <> cardinality(p_invitee_ids) then
    raise exception 'duplicate_invitee' using errcode = '22023';
  end if;
  if v_user = any(p_invitee_ids) then
    raise exception 'cannot_invite_self' using errcode = '22023';
  end if;
  if exists (
    select 1 from unnest(p_invitee_ids) as invitee(id)
    where not public.are_friends(v_user, invitee.id)
  ) then
    raise exception 'invitee_not_friend' using errcode = '22023';
  end if;

  insert into public.matches (
    organizer_id,
    format,
    starts_at,
    timezone,
    duration_minutes,
    location_name,
    location_details,
    status,
    version
  )
  values (
    v_user,
    p_format,
    p_starts_at,
    v_timezone,
    p_duration_minutes,
    btrim(p_location_name),
    nullif(btrim(coalesce(p_location_details, '')), ''),
    'awaiting_players',
    1
  )
  returning id into v_match_id;

  insert into public.match_participants (
    match_id,
    user_id,
    role,
    response,
    responded_at
  )
  values (v_match_id, v_user, 'organizer', 'accepted', now());

  insert into public.match_participants (match_id, user_id, role, response)
  select v_match_id, invitee.id, 'player', 'invited'
  from unnest(p_invitee_ids) as invitee(id);

  insert into public.match_events (match_id, type, description)
  values (v_match_id, 'created', 'Partido creado.');

  foreach v_invitee in array p_invitee_ids loop
    select display_name into v_name
    from public.profiles
    where id = v_invitee;

    insert into public.match_events (match_id, type, description)
    values (
      v_match_id,
      'invited',
      'Invitación enviada a ' || coalesce(v_name, 'un jugador') || '.'
    );
  end loop;

  return query select v_match_id, 'awaiting_players'::text;
end;
$$;

revoke all on function public.create_match(
  text, timestamptz, text, int, text, text, uuid[]
) from public, anon;
grant execute on function public.create_match(
  text, timestamptz, text, int, text, text, uuid[]
) to authenticated;

-- 4) Aceptar o rechazar una invitación.
create or replace function public.respond_match_invitation(
  p_match_id uuid,
  p_accept boolean
)
returns table (responded_match_id uuid, responded_status text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_match public.matches%rowtype;
  v_participant public.match_participants%rowtype;
  v_max_players int;
  v_accepted int;
  v_status text;
  v_name text;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_accept is null then
    raise exception 'invalid_response' using errcode = '22023';
  end if;

  select * into v_match
  from public.matches
  where id = p_match_id
  for update;

  if v_match.id is null then
    raise exception 'match_not_found' using errcode = 'P0002';
  end if;
  if v_match.status not in ('awaiting_players', 'confirmed') then
    raise exception 'match_not_active' using errcode = 'P0001';
  end if;

  select * into v_participant
  from public.match_participants
  where match_id = p_match_id
    and user_id = v_user
  for update;

  if v_participant.id is null then
    raise exception 'invitation_not_found' using errcode = 'P0002';
  end if;
  if v_participant.response <> 'invited' then
    raise exception 'invitation_not_pending' using errcode = 'P0001';
  end if;

  update public.match_participants
  set response = case when p_accept then 'accepted' else 'declined' end,
      responded_at = now()
  where id = v_participant.id;

  select display_name into v_name
  from public.profiles
  where id = v_user;

  insert into public.match_events (match_id, type, description)
  values (
    p_match_id,
    'responded',
    case
      when p_accept then 'Invitación aceptada por '
      else 'Invitación rechazada por '
    end || coalesce(v_name, 'un jugador') || '.'
  );

  v_max_players := case v_match.format
    when 'singles' then 2
    when 'doubles' then 4
  end;

  select count(*) into v_accepted
  from public.match_participants
  where match_id = p_match_id
    and response = 'accepted';

  update public.matches
  set status = case
        when v_accepted >= v_max_players then 'confirmed'
        else v_match.status
      end,
      version = version + 1
  where id = p_match_id
  returning status into v_status;

  return query select p_match_id, v_status;
end;
$$;

revoke all on function public.respond_match_invitation(uuid, boolean)
  from public, anon;
grant execute on function public.respond_match_invitation(uuid, boolean)
  to authenticated;

-- 5) Invitar jugadores adicionales o reemplazos desde el detalle.
create or replace function public.invite_match_players(
  p_match_id uuid,
  p_invitee_ids uuid[]
)
returns table (target_match_id uuid, current_status text, invited_count int)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_match public.matches%rowtype;
  v_participant public.match_participants%rowtype;
  v_max_players int;
  v_active int;
  v_name text;
  v_invitee uuid;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_invitee_ids is null or cardinality(p_invitee_ids) < 1 then
    raise exception 'invitees_required' using errcode = '22023';
  end if;
  if exists (
    select 1 from unnest(p_invitee_ids) as invitee(id)
    where invitee.id is null
  ) then
    raise exception 'invalid_invitee' using errcode = '22023';
  end if;
  if (
    select count(distinct invitee.id)
    from unnest(p_invitee_ids) as invitee(id)
  ) <> cardinality(p_invitee_ids) then
    raise exception 'duplicate_invitee' using errcode = '22023';
  end if;
  if v_user = any(p_invitee_ids) then
    raise exception 'cannot_invite_self' using errcode = '22023';
  end if;

  select * into v_match
  from public.matches
  where id = p_match_id
  for update;

  if v_match.id is null then
    raise exception 'match_not_found' using errcode = 'P0002';
  end if;
  if v_match.organizer_id <> v_user then
    raise exception 'not_organizer' using errcode = '42501';
  end if;
  if v_match.status not in ('awaiting_players', 'confirmed') then
    raise exception 'match_not_active' using errcode = 'P0001';
  end if;

  v_max_players := case v_match.format
    when 'singles' then 2
    when 'doubles' then 4
  end;

  if exists (
    select 1 from unnest(p_invitee_ids) as invitee(id)
    where not public.are_friends(v_user, invitee.id)
  ) then
    raise exception 'invitee_not_friend' using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.match_participants mp
    where mp.match_id = p_match_id
      and mp.user_id = any(p_invitee_ids)
      and mp.response in ('invited', 'accepted')
  ) then
    raise exception 'invitee_already_in_match' using errcode = 'P0001';
  end if;

  select count(*) into v_active
  from public.match_participants
  where match_id = p_match_id
    and response in ('invited', 'accepted');

  if v_active + cardinality(p_invitee_ids) > v_max_players then
    raise exception 'too_many_players' using errcode = 'P0001';
  end if;

  foreach v_invitee in array p_invitee_ids loop
    select display_name into v_name
    from public.profiles
    where id = v_invitee;

    select * into v_participant
    from public.match_participants
    where match_id = p_match_id
      and user_id = v_invitee
    for update;

    if v_participant.id is not null then
      update public.match_participants
      set response = 'invited',
          invited_at = now(),
          responded_at = null
      where id = v_participant.id;
    else
      insert into public.match_participants (
        match_id,
        user_id,
        role,
        response
      )
      values (p_match_id, v_invitee, 'player', 'invited');
    end if;

    insert into public.match_events (match_id, type, description)
    values (
      p_match_id,
      'invited',
      'Invitación enviada a ' || coalesce(v_name, 'un jugador') || '.'
    );
  end loop;

  update public.matches
  set version = version + 1
  where id = p_match_id;

  return query
    select p_match_id, v_match.status, cardinality(p_invitee_ids);
end;
$$;

revoke all on function public.invite_match_players(uuid, uuid[])
  from public, anon;
grant execute on function public.invite_match_players(uuid, uuid[])
  to authenticated;

-- 6) Realtime para que las listas y el detalle se actualicen sin refrescar.
alter table public.matches replica identity full;
alter table public.match_participants replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'matches'
  ) then
    alter publication supabase_realtime add table public.matches;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'match_participants'
  ) then
    alter publication supabase_realtime add table public.match_participants;
  end if;
end $$;
