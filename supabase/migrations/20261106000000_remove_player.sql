-- Etapa 5 (ampliación): el organizador puede eliminar a un jugador del partido
-- (por ejemplo, alguien que ya no podrá asistir).
--
-- Reglas:
--   - Solo el organizador puede eliminar a otro jugador.
--   - No puede eliminarse a sí mismo: para eso cancela el partido.
--   - Solo se puede eliminar a jugadores activos (invitados o aceptados).
--   - Al eliminarlo, su plaza queda libre y el partido vuelve a
--     'awaiting_players' si deja de estar completo.
--
-- El cliente no escribe directamente en las tablas: la mutación pasa por una
-- RPC SECURITY DEFINER.

-- 1) Nuevos estados: respuesta 'removed' y evento 'removed'.
alter table public.match_participants
  drop constraint if exists match_participants_response_check;
alter table public.match_participants
  add constraint match_participants_response_check
  check (response in ('invited', 'accepted', 'declined', 'withdrawn', 'removed'));

alter table public.match_events
  drop constraint if exists match_events_type_check;
alter table public.match_events
  add constraint match_events_type_check
  check (type in (
    'created', 'invited', 'responded', 'proposed', 'rescheduled',
    'cancelled', 'completed', 'withdrawn', 'reschedule_rejected', 'removed'
  ));

-- 2) RPC: eliminar a un jugador activo (solo el organizador).
create or replace function public.remove_match_player(
  p_match_id uuid,
  p_user_id uuid
)
returns table (
  target_match_id uuid,
  resulting_status text,
  removed_user_id uuid
)
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
  if p_user_id is null then
    raise exception 'invalid_player' using errcode = '22023';
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
  if p_user_id = v_user then
    raise exception 'cannot_remove_self' using errcode = 'P0001';
  end if;

  select * into v_participant
  from public.match_participants
  where match_id = p_match_id
    and user_id = p_user_id
  for update;

  if v_participant.id is null then
    raise exception 'participant_not_found' using errcode = 'P0002';
  end if;
  if v_participant.response not in ('invited', 'accepted') then
    raise exception 'player_not_removable' using errcode = 'P0001';
  end if;

  update public.match_participants
  set response = 'removed',
      responded_at = now()
  where id = v_participant.id;

  -- Los votos del jugador eliminado dejan de contar para propuestas pendientes.
  delete from public.match_proposal_votes
  where user_id = p_user_id
    and proposal_id in (
      select id
      from public.match_proposals
      where match_id = p_match_id
        and status = 'pending'
    );

  select display_name into v_name
  from public.profiles
  where id = p_user_id;

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
    'removed',
    'El organizador eliminó a ' || coalesce(v_name, 'un jugador') || ' del partido.'
  );

  return query select p_match_id, v_status, p_user_id;
end;
$$;

revoke all on function public.remove_match_player(uuid, uuid) from public, anon;
grant execute on function public.remove_match_player(uuid, uuid) to authenticated;
