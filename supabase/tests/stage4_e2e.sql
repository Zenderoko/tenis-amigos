-- E2E de backend para la Etapa 4.
-- Ejecutar completo (Ctrl+A) en el SQL Editor de Supabase.
--
-- Todo el estado vive en variables locales de un único bloque DO y las 28
-- comprobaciones se guardan en public._stage4_e2e_results. Así no dependemos
-- de tablas temporales, de ROLLBACK ni de estado entre sentencias.
-- Si algo falla, la tabla contiene una fila ERROR con el mensaje de Postgres.
--
-- Requiere que existan los usuarios:
--   amonsalveru@gmail.com
--   amonsalveru+e2e@gmail.com
-- No hace falta que la cuenta secundaria esté confirmada: se simulan las
-- sesiones con los claims de Supabase Auth.

do $$
declare
  v_primary uuid;
  v_secondary uuid;
  v_friend_status text;
  v_friendship_created boolean := false;

  v_match uuid;
  v_singles_match uuid;
  v_doubles_match uuid;
  v_status text;
  v_version int;
  v_events int;
  v_count int;

  v_random uuid;
  v_matches int;
  v_players int;

  v_error text;
  v_response text;
  v_accepted int;
begin
  execute 'drop table if exists public._stage4_e2e_results';
  execute '
    create table public._stage4_e2e_results (
      step text primary key,
      ok boolean not null,
      detail text
    )
  ';
  execute
    'revoke all on public._stage4_e2e_results from anon, authenticated';

  -- Si algo falla dentro de este bloque, se revierte todo lo creado y se
  -- guarda el error en la tabla de resultados para que el SELECT final lo vea.
  begin
    -- Limpieza de restos de ejecuciones anteriores interrumpidas.
  delete from public.matches
  where location_name like 'Cancha E2E%'
    and organizer_id in (
      select id from auth.users
      where email in ('amonsalveru@gmail.com', 'amonsalveru+e2e@gmail.com')
    );

  -- 1) Usuarios y amistad aceptada.
  select id into v_primary
  from auth.users
  where email = 'amonsalveru@gmail.com'
  limit 1;

  select id into v_secondary
  from auth.users
  where email = 'amonsalveru+e2e@gmail.com'
  limit 1;

  if v_primary is null then
    raise exception 'No existe el usuario amonsalveru@gmail.com';
  end if;
  if v_secondary is null then
    raise exception
      'No existe amonsalveru+e2e@gmail.com. Créalo desde la app o el dashboard.';
  end if;

  select f.status into v_friend_status
  from public.friendships f
  where (f.user_id = v_primary and f.friend_id = v_secondary)
     or (f.user_id = v_secondary and f.friend_id = v_primary)
  limit 1;

  if v_friend_status is null then
    insert into public.friendships (user_id, friend_id, status)
    values (v_primary, v_secondary, 'accepted');
    v_friendship_created := true;
  elsif v_friend_status <> 'accepted' then
    raise exception
      'La amistad E2E existe con estado "%". Acéptala o elimínala antes de ejecutar la prueba.',
      v_friend_status;
  end if;

  insert into public._stage4_e2e_results (step, ok, detail)
  values (
    '01 usuarios y amistad',
    true,
    v_primary::text || ' / ' || v_secondary::text
  );

  -- 2) Crear un singles como usuario primario.
  perform set_config('request.jwt.claim.sub', v_primary::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_primary, 'role', 'authenticated')::text,
    true
  );

  select created_match_id, created_status
  into v_match, v_status
  from public.create_match(
    'singles',
    date_trunc('minute', now()) + interval '2 days',
    'America/Santiago',
    90,
    'Cancha E2E',
    'Prueba automatizada',
    array[v_secondary]
  );

  v_singles_match := v_match;

  insert into public._stage4_e2e_results (step, ok, detail)
  values (
    '02 crear singles',
    v_match is not null and v_status = 'awaiting_players',
    coalesce(v_match::text, 'sin id') || ' / ' || coalesce(v_status, 'sin estado')
  );

  -- 3) Estado inicial del singles.
  select count(*) into v_count
  from public.match_participants
  where match_id = v_singles_match;

  insert into public._stage4_e2e_results (step, ok, detail)
  values ('03 dos participantes', v_count = 2, v_count::text);

  insert into public._stage4_e2e_results (step, ok, detail)
  select
    '04 organizador aceptado',
    count(*) = 1,
    count(*)::text
  from public.match_participants
  where match_id = v_singles_match
    and response = 'accepted'
    and role = 'organizer';

  insert into public._stage4_e2e_results (step, ok, detail)
  select
    '05 invitado pendiente',
    count(*) = 1,
    count(*)::text
  from public.match_participants
  where match_id = v_singles_match
    and response = 'invited';

  insert into public._stage4_e2e_results (step, ok, detail)
  select
    '06 eventos creado e invitación',
    count(*) = 2,
    count(*)::text
  from public.match_events
  where match_id = v_singles_match
    and type in ('created', 'invited');

  -- 4) RLS: el invitado ve el partido y a todos los jugadores.
  perform set_config('request.jwt.claim.sub', v_secondary::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_secondary, 'role', 'authenticated')::text,
    true
  );

  execute 'set local role authenticated';
  select count(*) into v_count from public.matches where id = v_singles_match;
  execute 'reset role';

  insert into public._stage4_e2e_results (step, ok, detail)
  values ('07 RLS invitado ve partido', v_count = 1, v_count::text);

  execute 'set local role authenticated';
  select count(*) into v_count
  from public.match_participants
  where match_id = v_singles_match;
  execute 'reset role';

  insert into public._stage4_e2e_results (step, ok, detail)
  values ('08 RLS invitado ve jugadores', v_count = 2, v_count::text);

  -- 5) RLS: alguien ajeno no ve el partido.
  v_random := gen_random_uuid();
  perform set_config('request.jwt.claim.sub', v_random::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_random, 'role', 'authenticated')::text,
    true
  );

  execute 'set local role authenticated';
  select count(*) into v_matches from public.matches where id = v_singles_match;
  execute 'reset role';

  execute 'set local role authenticated';
  select count(*) into v_players
  from public.match_participants
  where match_id = v_singles_match;
  execute 'reset role';

  insert into public._stage4_e2e_results (step, ok, detail)
  values ('09 RLS ajeno sin partido', v_matches = 0, v_matches::text);

  insert into public._stage4_e2e_results (step, ok, detail)
  values ('10 RLS ajeno sin jugadores', v_players = 0, v_players::text);

  -- 6) El invitado acepta y el singles queda confirmado.
  perform set_config('request.jwt.claim.sub', v_secondary::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_secondary, 'role', 'authenticated')::text,
    true
  );

  select responded_status into v_status
  from public.respond_match_invitation(v_singles_match, true);

  insert into public._stage4_e2e_results (step, ok, detail)
  values (
    '11 aceptar invitación',
    v_status = 'confirmed',
    coalesce(v_status, 'sin estado')
  );

  select status, version into v_status, v_version
  from public.matches
  where id = v_singles_match;

  insert into public._stage4_e2e_results (step, ok, detail)
  values (
    '12 singles confirmado',
    v_status = 'confirmed' and v_version = 2,
    coalesce(v_status, 'sin estado') || ' / v' || v_version
  );

  select count(*) into v_events
  from public.match_events
  where match_id = v_singles_match
    and type = 'responded';

  insert into public._stage4_e2e_results (step, ok, detail)
  values ('13 evento de respuesta', v_events = 1, v_events::text);

  -- 7) No se puede responder dos veces la misma invitación.
  begin
    perform 1 from public.respond_match_invitation(v_singles_match, true);
    insert into public._stage4_e2e_results (step, ok, detail)
    values ('14 doble respuesta bloqueada', false, 'no lanzó error');
  exception when others then
    v_error := SQLERRM;
    insert into public._stage4_e2e_results (step, ok, detail)
    values (
      '14 doble respuesta bloqueada',
      position('invitation_not_pending' in v_error) > 0,
      v_error
    );
  end;

  -- 8) Validaciones negativas al crear.
  perform set_config('request.jwt.claim.sub', v_primary::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_primary, 'role', 'authenticated')::text,
    true
  );

  begin
    perform 1 from public.create_match(
      'singles',
      date_trunc('minute', now()) + interval '2 days',
      'America/Santiago',
      90,
      'Cancha E2E',
      null,
      array[v_primary]
    );
    insert into public._stage4_e2e_results (step, ok, detail)
    values ('15 autoinvitación bloqueada', false, 'no lanzó error');
  exception when others then
    v_error := SQLERRM;
    insert into public._stage4_e2e_results (step, ok, detail)
    values (
      '15 autoinvitación bloqueada',
      position('cannot_invite_self' in v_error) > 0,
      v_error
    );
  end;

  begin
    perform 1 from public.create_match(
      'singles',
      date_trunc('minute', now()) + interval '2 days',
      'America/Santiago',
      90,
      'Cancha E2E',
      null,
      array[v_secondary, v_secondary]
    );
    insert into public._stage4_e2e_results (step, ok, detail)
    values ('16 invitado duplicado bloqueado', false, 'no lanzó error');
  exception when others then
    v_error := SQLERRM;
    insert into public._stage4_e2e_results (step, ok, detail)
    values (
      '16 invitado duplicado bloqueado',
      position('duplicate_invitee' in v_error) > 0,
      v_error
    );
  end;

  begin
    perform 1 from public.create_match(
      'singles',
      date_trunc('minute', now()) + interval '2 days',
      'America/Santiago',
      90,
      'Cancha E2E',
      null,
      array[]::uuid[]
    );
    insert into public._stage4_e2e_results (step, ok, detail)
    values ('17 sin invitados bloqueado', false, 'no lanzó error');
  exception when others then
    v_error := SQLERRM;
    insert into public._stage4_e2e_results (step, ok, detail)
    values (
      '17 sin invitados bloqueado',
      position('invitees_required' in v_error) > 0,
      v_error
    );
  end;

  begin
    perform 1 from public.create_match(
      'singles',
      date_trunc('minute', now()) + interval '2 days',
      'America/Santiago',
      45,
      'Cancha E2E',
      null,
      array[v_secondary]
    );
    insert into public._stage4_e2e_results (step, ok, detail)
    values ('18 duración inválida bloqueada', false, 'no lanzó error');
  exception when others then
    v_error := SQLERRM;
    insert into public._stage4_e2e_results (step, ok, detail)
    values (
      '18 duración inválida bloqueada',
      position('invalid_duration' in v_error) > 0,
      v_error
    );
  end;

  begin
    perform 1 from public.create_match(
      'singles',
      date_trunc('minute', now()) - interval '1 day',
      'America/Santiago',
      90,
      'Cancha E2E',
      null,
      array[v_secondary]
    );
    insert into public._stage4_e2e_results (step, ok, detail)
    values ('19 fecha pasada bloqueada', false, 'no lanzó error');
  exception when others then
    v_error := SQLERRM;
    insert into public._stage4_e2e_results (step, ok, detail)
    values (
      '19 fecha pasada bloqueada',
      position('invalid_start_time' in v_error) > 0,
      v_error
    );
  end;

  begin
    perform 1 from public.create_match(
      'triples',
      date_trunc('minute', now()) + interval '2 days',
      'America/Santiago',
      90,
      'Cancha E2E',
      null,
      array[v_secondary]
    );
    insert into public._stage4_e2e_results (step, ok, detail)
    values ('20 modalidad inválida bloqueada', false, 'no lanzó error');
  exception when others then
    v_error := SQLERRM;
    insert into public._stage4_e2e_results (step, ok, detail)
    values (
      '20 modalidad inválida bloqueada',
      position('invalid_format' in v_error) > 0,
      v_error
    );
  end;

  -- 9) Dobles: rechazo, reinvitación y aceptación.
  perform set_config('request.jwt.claim.sub', v_primary::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_primary, 'role', 'authenticated')::text,
    true
  );

  select created_match_id, created_status
  into v_match, v_status
  from public.create_match(
    'doubles',
    date_trunc('minute', now()) + interval '3 days',
    'America/Santiago',
    75,
    'Cancha E2E Dobles',
    null,
    array[v_secondary]
  );

  v_doubles_match := v_match;

  insert into public._stage4_e2e_results (step, ok, detail)
  values (
    '21 crear dobles',
    v_match is not null and v_status = 'awaiting_players',
    coalesce(v_match::text, 'sin id')
  );

  perform set_config('request.jwt.claim.sub', v_secondary::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_secondary, 'role', 'authenticated')::text,
    true
  );

  perform 1 from public.respond_match_invitation(v_doubles_match, false);

  select response into v_response
  from public.match_participants
  where match_id = v_doubles_match
    and user_id = v_secondary;

  insert into public._stage4_e2e_results (step, ok, detail)
  values ('22 rechazar invitación', v_response = 'declined', v_response);

  perform set_config('request.jwt.claim.sub', v_primary::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_primary, 'role', 'authenticated')::text,
    true
  );

  perform 1 from public.invite_match_players(v_doubles_match, array[v_secondary]);

  select response into v_response
  from public.match_participants
  where match_id = v_doubles_match
    and user_id = v_secondary;

  insert into public._stage4_e2e_results (step, ok, detail)
  values ('23 reinvitar reemplazo', v_response = 'invited', v_response);

  perform set_config('request.jwt.claim.sub', v_secondary::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_secondary, 'role', 'authenticated')::text,
    true
  );

  select responded_status into v_status
  from public.respond_match_invitation(v_doubles_match, true);

  select count(*) into v_accepted
  from public.match_participants
  where match_id = v_doubles_match
    and response = 'accepted';

  insert into public._stage4_e2e_results (step, ok, detail)
  values (
    '24 dobles sigue esperando',
    v_status = 'awaiting_players' and v_accepted = 2,
    coalesce(v_status, 'sin estado') || ' / ' || v_accepted || ' aceptados'
  );

  -- 10) Solo el organizador invita y solo a amistades.
  perform set_config('request.jwt.claim.sub', v_secondary::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_secondary, 'role', 'authenticated')::text,
    true
  );

  begin
    perform 1 from public.invite_match_players(v_doubles_match, array[v_primary]);
    insert into public._stage4_e2e_results (step, ok, detail)
    values ('25 no organizador bloqueado', false, 'no lanzó error');
  exception when others then
    v_error := SQLERRM;
    insert into public._stage4_e2e_results (step, ok, detail)
    values (
      '25 no organizador bloqueado',
      position('not_organizer' in v_error) > 0,
      v_error
    );
  end;

  perform set_config('request.jwt.claim.sub', v_primary::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_primary, 'role', 'authenticated')::text,
    true
  );

  begin
    perform 1 from public.invite_match_players(
      v_doubles_match,
      array[gen_random_uuid()]
    );
    insert into public._stage4_e2e_results (step, ok, detail)
    values ('26 no amistad bloqueada', false, 'no lanzó error');
  exception when others then
    v_error := SQLERRM;
    insert into public._stage4_e2e_results (step, ok, detail)
    values (
      '26 no amistad bloqueada',
      position('invitee_not_friend' in v_error) > 0,
      v_error
    );
  end;

  -- 11) Realtime.
  insert into public._stage4_e2e_results (step, ok, detail)
  select
    '27 realtime matches',
    exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'matches'
    ),
    'publicación supabase_realtime';

  insert into public._stage4_e2e_results (step, ok, detail)
  select
    '28 realtime participantes',
    exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'match_participants'
    ),
    'publicación supabase_realtime';

  -- Limpieza de los datos creados por esta ejecución.
  delete from public.matches
  where organizer_id in (v_primary, v_secondary)
    and location_name like 'Cancha E2E%';

  if v_friendship_created then
    delete from public.friendships
    where (user_id = v_primary and friend_id = v_secondary)
       or (user_id = v_secondary and friend_id = v_primary);
  end if;
  exception when others then
    execute 'reset role';
    insert into public._stage4_e2e_results (step, ok, detail)
    values ('ERROR', false, SQLERRM);
  end;

  perform set_config('request.jwt.claim.sub', null, false);
  perform set_config('request.jwt.claims', null, false);
end $$;

select step, ok, detail
from public._stage4_e2e_results
order by step;

-- La tabla de resultados se elimina al inicio de la próxima ejecución.
-- Para borrarla ahora: drop table if exists public._stage4_e2e_results;
