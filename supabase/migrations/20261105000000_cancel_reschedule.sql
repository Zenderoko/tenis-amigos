-- Etapa 5: cancelación, retiro y reprogramación de partidos.
--
-- Política de reprogramación (sencilla y documentada):
--   - Solo el organizador propone un nuevo horario.
--   - La fecha oficial NO cambia hasta que la propuesta se apruebe.
--   - Deben aprobarla todos los jugadores aceptados (sin contar al organizador);
--     un solo rechazo descarta la propuesta.
--   - Solo puede existir una propuesta pendiente por partido: una nueva
--     reemplaza a la anterior.
--
-- El cliente no escribe directamente en las tablas: todas las mutaciones pasan
-- por RPC SECURITY DEFINER.

-- 1) Tipos de evento ampliados (retiro y rechazo de reprogramación).
alter table public.match_events drop constraint if exists match_events_type_check;
alter table public.match_events add constraint match_events_type_check
  check (type in (
    'created', 'invited', 'responded', 'proposed', 'rescheduled',
    'cancelled', 'completed', 'withdrawn', 'reschedule_rejected'
  ));

-- 2) Votos de las propuestas de reprogramación.
create table if not exists public.match_proposal_votes (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.match_proposals(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  response text not null check (response in ('accepted', 'rejected')),
  responded_at timestamptz not null default now(),
  unique (proposal_id, user_id)
);

create index if not exists match_proposal_votes_proposal_id_idx
  on public.match_proposal_votes (proposal_id);
create index if not exists match_proposals_match_id_idx
  on public.match_proposals (match_id);
create index if not exists match_proposals_pending_idx
  on public.match_proposals (match_id)
  where status = 'pending';

alter table public.match_proposal_votes enable row level security;

drop policy if exists "match_proposal_votes_select_related"
  on public.match_proposal_votes;
create policy "match_proposal_votes_select_related"
  on public.match_proposal_votes
  for select to authenticated
  using (
    exists (
      select 1
      from public.match_proposals p
      where p.id = proposal_id
        and (
          public.is_match_participant(p.match_id, auth.uid())
          or public.is_match_organizer(p.match_id, auth.uid())
        )
    )
  );

-- 3) Las mutaciones pasan por RPC. Se revocan las escrituras directas.
drop policy if exists "match_proposals_insert_related" on public.match_proposals;
drop policy if exists "match_proposals_update_resolver" on public.match_proposals;
revoke insert, update, delete on public.match_proposals from anon, authenticated;
revoke insert, update, delete on public.match_proposal_votes from anon, authenticated;

-- 4) Cancelar un partido activo (solo el organizador).
create or replace function public.cancel_match(p_match_id uuid)
returns table (cancelled_match_id uuid, cancelled_status text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_match public.matches%rowtype;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
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

  update public.match_proposals
  set status = 'superseded', resolved_at = now()
  where match_id = p_match_id
    and status = 'pending';

  update public.matches
  set status = 'cancelled',
      version = version + 1
  where id = p_match_id;

  insert into public.match_events (match_id, type, description)
  values (p_match_id, 'cancelled', 'Partido cancelado por el organizador.');

  return query select p_match_id, 'cancelled'::text;
end;
$$;

revoke all on function public.cancel_match(uuid) from public, anon;
grant execute on function public.cancel_match(uuid) to authenticated;

-- 5) Retirarse de un partido activo (un jugador aceptado que no organiza).
create or replace function public.withdraw_from_match(p_match_id uuid)
returns table (withdrawn_match_id uuid, resulting_status text)
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
  if v_match.organizer_id = v_user then
    raise exception 'cannot_withdraw_organizer' using errcode = 'P0001';
  end if;

  select * into v_participant
  from public.match_participants
  where match_id = p_match_id
    and user_id = v_user
  for update;

  if v_participant.id is null then
    raise exception 'invitation_not_found' using errcode = 'P0002';
  end if;
  if v_participant.response <> 'accepted' then
    raise exception 'withdraw_not_allowed' using errcode = 'P0001';
  end if;

  update public.match_participants
  set response = 'withdrawn',
      responded_at = now()
  where id = v_participant.id;

  select display_name into v_name
  from public.profiles
  where id = v_user;

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
        else 'awaiting_players'
      end,
      version = version + 1
  where id = p_match_id
  returning status into v_status;

  insert into public.match_events (match_id, type, description)
  values (
    p_match_id,
    'withdrawn',
    coalesce(v_name, 'Un jugador') || ' se retiró del partido.'
  );

  return query select p_match_id, v_status;
end;
$$;

revoke all on function public.withdraw_from_match(uuid) from public, anon;
grant execute on function public.withdraw_from_match(uuid) to authenticated;

-- 6) Proponer una reprogramación (solo el organizador).
create or replace function public.propose_reschedule(
  p_match_id uuid,
  p_starts_at timestamptz,
  p_timezone text
)
returns table (proposal_id uuid, proposal_status text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_match public.matches%rowtype;
  v_timezone text := coalesce(
    nullif(btrim(p_timezone), ''),
    'America/Santiago'
  );
  v_proposal_id uuid;
  v_needed int;
  v_status text := 'pending';
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
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
  if p_starts_at is null or p_starts_at <= now() then
    raise exception 'invalid_start_time' using errcode = '22023';
  end if;
  if not exists (select 1 from pg_timezone_names where name = v_timezone) then
    raise exception 'invalid_timezone' using errcode = '22023';
  end if;

  update public.match_proposals
  set status = 'superseded', resolved_at = now()
  where match_id = p_match_id
    and status = 'pending';

  insert into public.match_proposals (
    match_id,
    proposed_by,
    proposed_starts_at,
    proposed_timezone,
    status
  )
  values (p_match_id, v_user, p_starts_at, v_timezone, 'pending')
  returning id into v_proposal_id;

  insert into public.match_events (match_id, type, description)
  values (
    p_match_id,
    'proposed',
    'El organizador propuso reprogramar el partido.'
  );

  select count(*) into v_needed
  from public.match_participants
  where match_id = p_match_id
    and response = 'accepted'
    and user_id <> v_user;

  if v_needed = 0 then
    update public.matches
    set starts_at = p_starts_at,
        timezone = v_timezone,
        version = version + 1
    where id = p_match_id;

    update public.match_proposals
    set status = 'accepted', resolved_at = now()
    where id = v_proposal_id;

    insert into public.match_events (match_id, type, description)
    values (
      p_match_id,
      'rescheduled',
      'Horario actualizado (no había otros jugadores confirmados).'
    );

    v_status := 'accepted';
  else
    update public.matches
    set version = version + 1
    where id = p_match_id;
  end if;

  return query select v_proposal_id, v_status;
end;
$$;

revoke all on function public.propose_reschedule(uuid, timestamptz, text)
  from public, anon;
grant execute on function public.propose_reschedule(uuid, timestamptz, text)
  to authenticated;

-- 7) Aceptar o rechazar una propuesta de reprogramación.
create or replace function public.respond_reschedule(
  p_proposal_id uuid,
  p_accept boolean
)
returns table (resolved_proposal_id uuid, resolved_status text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_proposal public.match_proposals%rowtype;
  v_match public.matches%rowtype;
  v_needed int;
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

  select * into v_proposal
  from public.match_proposals
  where id = p_proposal_id
  for update;

  if v_proposal.id is null then
    raise exception 'proposal_not_found' using errcode = 'P0002';
  end if;
  if v_proposal.status <> 'pending' then
    raise exception 'proposal_not_pending' using errcode = 'P0001';
  end if;

  select * into v_match
  from public.matches
  where id = v_proposal.match_id
  for update;

  if v_match.status not in ('awaiting_players', 'confirmed') then
    raise exception 'match_not_active' using errcode = 'P0001';
  end if;
  if v_proposal.proposed_by = v_user then
    raise exception 'cannot_vote_own_proposal' using errcode = 'P0001';
  end if;
  if not exists (
    select 1
    from public.match_participants
    where match_id = v_proposal.match_id
      and user_id = v_user
      and response = 'accepted'
  ) then
    raise exception 'not_accepted_participant' using errcode = 'P0001';
  end if;

  insert into public.match_proposal_votes (
    proposal_id,
    user_id,
    response,
    responded_at
  )
  values (
    p_proposal_id,
    v_user,
    case when p_accept then 'accepted' else 'rejected' end,
    now()
  )
  on conflict (proposal_id, user_id)
  do update set response = excluded.response, responded_at = now();

  select display_name into v_name
  from public.profiles
  where id = v_user;

  if not p_accept then
    update public.match_proposals
    set status = 'rejected', resolved_at = now()
    where id = p_proposal_id;

    update public.matches
    set version = version + 1
    where id = v_match.id;

    insert into public.match_events (match_id, type, description)
    values (
      v_match.id,
      'reschedule_rejected',
      'Reprogramación rechazada por ' || coalesce(v_name, 'un jugador') || '.'
    );

    v_status := 'rejected';
  else
    select count(*) into v_needed
    from public.match_participants
    where match_id = v_match.id
      and response = 'accepted'
      and user_id <> v_proposal.proposed_by;

    select count(*) into v_accepted
    from public.match_proposal_votes
    where proposal_id = p_proposal_id
      and response = 'accepted';

    if v_accepted >= v_needed then
      update public.matches
      set starts_at = v_proposal.proposed_starts_at,
          timezone = coalesce(v_proposal.proposed_timezone, timezone),
          version = version + 1
      where id = v_match.id;

      update public.match_proposals
      set status = 'accepted', resolved_at = now()
      where id = p_proposal_id;

      insert into public.match_events (match_id, type, description)
      values (
        v_match.id,
        'rescheduled',
        'Horario actualizado tras la aprobación de los jugadores.'
      );

      v_status := 'accepted';
    else
      update public.matches
      set version = version + 1
      where id = v_match.id;

      v_status := 'pending';
    end if;
  end if;

  return query select p_proposal_id, v_status;
end;
$$;

revoke all on function public.respond_reschedule(uuid, boolean) from public, anon;
grant execute on function public.respond_reschedule(uuid, boolean)
  to authenticated;

-- 8) Retirar una propuesta pendiente (solo el organizador).
create or replace function public.cancel_reschedule(p_proposal_id uuid)
returns table (cancelled_proposal_id uuid, cancelled_status text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_proposal public.match_proposals%rowtype;
  v_match public.matches%rowtype;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select * into v_proposal
  from public.match_proposals
  where id = p_proposal_id
  for update;

  if v_proposal.id is null then
    raise exception 'proposal_not_found' using errcode = 'P0002';
  end if;
  if v_proposal.status <> 'pending' then
    raise exception 'proposal_not_pending' using errcode = 'P0001';
  end if;

  select * into v_match
  from public.matches
  where id = v_proposal.match_id
  for update;

  if v_match.organizer_id <> v_user then
    raise exception 'not_organizer' using errcode = '42501';
  end if;

  update public.match_proposals
  set status = 'superseded', resolved_at = now()
  where id = p_proposal_id;

  update public.matches
  set version = version + 1
  where id = v_match.id;

  return query select p_proposal_id, 'superseded'::text;
end;
$$;

revoke all on function public.cancel_reschedule(uuid) from public, anon;
grant execute on function public.cancel_reschedule(uuid) to authenticated;

-- 9) Realtime: los cambios de propuestas se reflejan porque también se
-- incrementa matches.version, que ya está publicado en supabase_realtime.
alter table public.match_proposals replica identity full;
alter table public.match_proposal_votes replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'match_proposals'
  ) then
    alter publication supabase_realtime add table public.match_proposals;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'match_proposal_votes'
  ) then
    alter publication supabase_realtime add table public.match_proposal_votes;
  end if;
end $$;
