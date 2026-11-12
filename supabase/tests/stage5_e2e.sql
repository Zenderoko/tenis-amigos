-- E2E de backend para la Etapa 5 (calendario y reprogramación).
-- Ejecutar completo (Ctrl+A) en el SQL Editor de Supabase.
--
-- Todo el estado vive en variables locales de un único bloque DO y las
-- comprobaciones se guardan en public._stage5_e2e_results. Si algo falla, la
-- tabla contiene una fila ERROR con el mensaje de Postgres.
--
-- Requiere los usuarios:
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

  v_singles uuid;
  v_doubles uuid;
  v_proposal uuid;
  v_proposal_status text;
  v_status text;
  v_starts_before timestamptz;
  v_starts_after timestamptz;
  v_proposed timestamptz;
  v_count int;
  v_error text;
  v_random uuid;
  v_response text;
begin
  execute 'drop table if exists public._stage5_e2e_results';
  execute '
    create table public._stage5_e2e_results (
      step text primary key,
      ok boolean not null,
      detail text
    )
  ';
  execute 'revoke all on public._stage5_e2e_results from anon, authenticated';

  begin
    delete from public.matches
    where location_name like 'Cancha E2E5%'
      and organizer_id in (
        select id from auth.users
        where email in (
          'amonsalveru@gmail.com',
          'amonsalveru+e2e@gmail.com'
        )
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
      raise exception 'No existe amonsalveru+e2e@gmail.com.';
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
        'La amistad E2E existe con estado "%".',
        v_friend_status;
    end if;

    insert into public._stage5_e2e_results (step, ok, detail)
    values ('01 usuarios y amistad', true, 'ok');

    -- 2) Singles confirmado.
    perform set_config('request.jwt.claim.sub', v_primary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_primary, 'role', 'authenticated')::text,
      true
    );

    select created_match_id into v_singles
    from public.create_match(
      'singles',
      date_trunc('minute', now()) + interval '2 days',
      'America/Santiago',
      90,
      'Cancha E2E5 Singles',
      null,
      array[v_secondary]
    );

    perform set_config('request.jwt.claim.sub', v_secondary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_secondary, 'role', 'authenticated')::text,
      true
    );
    perform 1 from public.respond_match_invitation(v_singles, true);

    select status into v_status from public.matches where id = v_singles;

    insert into public._stage5_e2e_results (step, ok, detail)
    values ('02 singles confirmado', v_status = 'confirmed', v_status);

    -- 3) El organizador propone una reprogramación.
    perform set_config('request.jwt.claim.sub', v_primary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_primary, 'role', 'authenticated')::text,
      true
    );

    v_proposed := date_trunc('minute', now()) + interval '5 days';
    select proposal_id, proposal_status
    into v_proposal, v_proposal_status
    from public.propose_reschedule(
      v_singles,
      v_proposed,
      'America/Santiago'
    );

    insert into public._stage5_e2e_results (step, ok, detail)
    values (
      '03 propuesta pendiente',
      v_proposal is not null and v_proposal_status = 'pending',
      coalesce(v_proposal_status, 'sin estado')
    );

    select starts_at into v_starts_before from public.matches where id = v_singles;

    insert into public._stage5_e2e_results (step, ok, detail)
    values (
      '04 fecha oficial sin cambios',
      v_starts_before <> v_proposed,
      'la propuesta no cambia starts_at'
    );

    -- 4) El proponente no vota su propia propuesta.
    begin
      perform 1 from public.respond_reschedule(v_proposal, true);
      insert into public._stage5_e2e_results (step, ok, detail)
      values ('05 proponente no vota', false, 'no lanzó error');
    exception when others then
      v_error := SQLERRM;
      insert into public._stage5_e2e_results (step, ok, detail)
      values (
        '05 proponente no vota',
        position('cannot_vote_own_proposal' in v_error) > 0,
        v_error
      );
    end;

    -- 5) Un invitado sin aceptar no puede votar.
    v_random := gen_random_uuid();
    perform set_config('request.jwt.claim.sub', v_random::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_random, 'role', 'authenticated')::text,
      true
    );
    begin
      perform 1 from public.respond_reschedule(v_proposal, true);
      insert into public._stage5_e2e_results (step, ok, detail)
      values ('06 ajeno no vota', false, 'no lanzó error');
    exception when others then
      v_error := SQLERRM;
      insert into public._stage5_e2e_results (step, ok, detail)
      values (
        '06 ajeno no vota',
        position('not_accepted_participant' in v_error) > 0,
        v_error
      );
    end;

    -- 6) El jugador confirmado aprueba y se aplica el cambio.
    perform set_config('request.jwt.claim.sub', v_secondary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_secondary, 'role', 'authenticated')::text,
      true
    );
    select resolved_status into v_proposal_status
    from public.respond_reschedule(v_proposal, true);

    select starts_at into v_starts_after from public.matches where id = v_singles;

    insert into public._stage5_e2e_results (step, ok, detail)
    values (
      '07 reprogramación aprobada',
      v_proposal_status = 'accepted'
        and date_trunc('minute', v_starts_after) = date_trunc('minute', v_proposed),
      coalesce(v_proposal_status, 'sin estado')
    );

    select count(*) into v_count
    from public.match_events
    where match_id = v_singles and type = 'rescheduled';

    insert into public._stage5_e2e_results (step, ok, detail)
    values ('08 evento reprogramado', v_count = 1, v_count::text);

    -- 7) Rechazo: la fecha oficial no cambia.
    perform set_config('request.jwt.claim.sub', v_primary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_primary, 'role', 'authenticated')::text,
      true
    );
    select proposal_id into v_proposal
    from public.propose_reschedule(
      v_singles,
      date_trunc('minute', now()) + interval '8 days',
      'America/Santiago'
    );

    perform set_config('request.jwt.claim.sub', v_secondary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_secondary, 'role', 'authenticated')::text,
      true
    );
    select resolved_status into v_proposal_status
    from public.respond_reschedule(v_proposal, false);

    select starts_at into v_starts_before from public.matches where id = v_singles;

    insert into public._stage5_e2e_results (step, ok, detail)
    values (
      '09 reprogramación rechazada',
      v_proposal_status = 'rejected'
        and date_trunc('minute', v_starts_before) = date_trunc('minute', v_proposed),
      coalesce(v_proposal_status, 'sin estado')
    );

    select count(*) into v_count
    from public.match_events
    where match_id = v_singles and type = 'reschedule_rejected';

    insert into public._stage5_e2e_results (step, ok, detail)
    values ('10 evento rechazo', v_count = 1, v_count::text);

    -- 8) El organizador retira una propuesta pendiente.
    perform set_config('request.jwt.claim.sub', v_primary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_primary, 'role', 'authenticated')::text,
      true
    );
    select proposal_id into v_proposal
    from public.propose_reschedule(
      v_singles,
      date_trunc('minute', now()) + interval '10 days',
      'America/Santiago'
    );
    perform 1 from public.cancel_reschedule(v_proposal);

    select status into v_proposal_status
    from public.match_proposals where id = v_proposal;

    insert into public._stage5_e2e_results (step, ok, detail)
    values (
      '11 propuesta retirada',
      v_proposal_status = 'superseded',
      coalesce(v_proposal_status, 'sin estado')
    );

    -- 9) El invitado no puede cancelar ni proponer.
    perform set_config('request.jwt.claim.sub', v_secondary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_secondary, 'role', 'authenticated')::text,
      true
    );
    begin
      perform 1 from public.cancel_match(v_singles);
      insert into public._stage5_e2e_results (step, ok, detail)
      values ('12 no organizador no cancela', false, 'no lanzó error');
    exception when others then
      v_error := SQLERRM;
      insert into public._stage5_e2e_results (step, ok, detail)
      values (
        '12 no organizador no cancela',
        position('not_organizer' in v_error) > 0,
        v_error
      );
    end;

    begin
      perform 1 from public.propose_reschedule(
        v_singles,
        date_trunc('minute', now()) + interval '12 days',
        'America/Santiago'
      );
      insert into public._stage5_e2e_results (step, ok, detail)
      values ('13 no organizador no propone', false, 'no lanzó error');
    exception when others then
      v_error := SQLERRM;
      insert into public._stage5_e2e_results (step, ok, detail)
      values (
        '13 no organizador no propone',
        position('not_organizer' in v_error) > 0,
        v_error
      );
    end;

    -- 10) El organizador cancela el partido.
    perform set_config('request.jwt.claim.sub', v_primary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_primary, 'role', 'authenticated')::text,
      true
    );
    select cancelled_status into v_status
    from public.cancel_match(v_singles);

    insert into public._stage5_e2e_results (step, ok, detail)
    values ('14 cancelar partido', v_status = 'cancelled', v_status);

    select count(*) into v_count
    from public.match_events
    where match_id = v_singles and type = 'cancelled';

    insert into public._stage5_e2e_results (step, ok, detail)
    values ('15 evento cancelación', v_count = 1, v_count::text);

    begin
      perform 1 from public.cancel_match(v_singles);
      insert into public._stage5_e2e_results (step, ok, detail)
      values ('16 no recancelar', false, 'no lanzó error');
    exception when others then
      v_error := SQLERRM;
      insert into public._stage5_e2e_results (step, ok, detail)
      values (
        '16 no recancelar',
        position('match_not_active' in v_error) > 0,
        v_error
      );
    end;

    -- 11) Retiro en un dobles.
    perform set_config('request.jwt.claim.sub', v_primary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_primary, 'role', 'authenticated')::text,
      true
    );
    select created_match_id into v_doubles
    from public.create_match(
      'doubles',
      date_trunc('minute', now()) + interval '3 days',
      'America/Santiago',
      75,
      'Cancha E2E5 Dobles',
      null,
      array[v_secondary]
    );

    perform set_config('request.jwt.claim.sub', v_secondary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_secondary, 'role', 'authenticated')::text,
      true
    );
    perform 1 from public.respond_match_invitation(v_doubles, true);

    select resulting_status into v_status
    from public.withdraw_from_match(v_doubles);

    select response into v_response
    from public.match_participants
    where match_id = v_doubles and user_id = v_secondary;

    insert into public._stage5_e2e_results (step, ok, detail)
    values (
      '17 retiro de jugador',
      v_response = 'withdrawn' and v_status = 'awaiting_players',
      coalesce(v_response, 'sin respuesta') || ' / ' || coalesce(v_status, '')
    );

    select count(*) into v_count
    from public.match_events
    where match_id = v_doubles and type = 'withdrawn';

    insert into public._stage5_e2e_results (step, ok, detail)
    values ('18 evento retiro', v_count = 1, v_count::text);

    -- 12) El organizador no puede retirarse.
    perform set_config('request.jwt.claim.sub', v_primary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_primary, 'role', 'authenticated')::text,
      true
    );
    begin
      perform 1 from public.withdraw_from_match(v_doubles);
      insert into public._stage5_e2e_results (step, ok, detail)
      values ('19 organizador no se retira', false, 'no lanzó error');
    exception when others then
      v_error := SQLERRM;
      insert into public._stage5_e2e_results (step, ok, detail)
      values (
        '19 organizador no se retira',
        position('cannot_withdraw_organizer' in v_error) > 0,
        v_error
      );
    end;

    -- 13) Realtime de propuestas.
    insert into public._stage5_e2e_results (step, ok, detail)
    select
      '20 realtime propuestas',
      exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'match_proposals'
      ),
      'publicación supabase_realtime';

    -- Limpieza.
    delete from public.matches
    where organizer_id in (v_primary, v_secondary)
      and location_name like 'Cancha E2E5%';

    if v_friendship_created then
      delete from public.friendships
      where (user_id = v_primary and friend_id = v_secondary)
         or (user_id = v_secondary and friend_id = v_primary);
    end if;
  exception when others then
    execute 'reset role';
    insert into public._stage5_e2e_results (step, ok, detail)
    values ('ERROR', false, SQLERRM);
  end;

  perform set_config('request.jwt.claim.sub', null, false);
  perform set_config('request.jwt.claims', null, false);
end $$;

select step, ok, detail
from public._stage5_e2e_results
order by step;

-- La tabla de resultados se elimina al inicio de la próxima ejecución.
-- Para borrarla ahora: drop table if exists public._stage5_e2e_results;
