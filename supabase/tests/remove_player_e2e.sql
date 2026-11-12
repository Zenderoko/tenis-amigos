-- E2E de backend: el organizador elimina a un jugador del partido.
-- Ejecutar completo (Ctrl+A) en el SQL Editor de Supabase.
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
  v_status text;
  v_response text;
  v_count int;
  v_error text;
begin
  execute 'drop table if exists public._remove_player_e2e_results';
  execute '
    create table public._remove_player_e2e_results (
      step text primary key,
      ok boolean not null,
      detail text
    )
  ';
  execute 'revoke all on public._remove_player_e2e_results from anon, authenticated';

  begin
    delete from public.matches
    where location_name like 'Cancha E2E-RM%'
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
      raise exception 'La amistad E2E existe con estado "%".', v_friend_status;
    end if;

    insert into public._remove_player_e2e_results (step, ok, detail)
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
      'Cancha E2E-RM Singles',
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

    insert into public._remove_player_e2e_results (step, ok, detail)
    values ('02 singles confirmado', v_status = 'confirmed', v_status);

    -- 3) El organizador elimina al jugador confirmado.
    perform set_config('request.jwt.claim.sub', v_primary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_primary, 'role', 'authenticated')::text,
      true
    );
    select resulting_status into v_status
    from public.remove_match_player(v_singles, v_secondary);

    select response into v_response
    from public.match_participants
    where match_id = v_singles and user_id = v_secondary;

    insert into public._remove_player_e2e_results (step, ok, detail)
    values (
      '03 eliminar jugador',
      v_response = 'removed' and v_status = 'awaiting_players',
      coalesce(v_response, 'sin respuesta') || ' / ' || coalesce(v_status, '')
    );

    select count(*) into v_count
    from public.match_events
    where match_id = v_singles and type = 'removed';

    insert into public._remove_player_e2e_results (step, ok, detail)
    values ('04 evento eliminación', v_count = 1, v_count::text);

    -- 4) Un jugador no organizador no puede eliminar.
    perform set_config('request.jwt.claim.sub', v_secondary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_secondary, 'role', 'authenticated')::text,
      true
    );
    begin
      perform 1 from public.remove_match_player(v_singles, v_primary);
      insert into public._remove_player_e2e_results (step, ok, detail)
      values ('05 no organizador no elimina', false, 'no lanzó error');
    exception when others then
      v_error := SQLERRM;
      insert into public._remove_player_e2e_results (step, ok, detail)
      values (
        '05 no organizador no elimina',
        position('not_organizer' in v_error) > 0,
        v_error
      );
    end;

    -- 5) El organizador no puede eliminarse a sí mismo.
    perform set_config('request.jwt.claim.sub', v_primary::text, true);
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_primary, 'role', 'authenticated')::text,
      true
    );
    begin
      perform 1 from public.remove_match_player(v_singles, v_primary);
      insert into public._remove_player_e2e_results (step, ok, detail)
      values ('06 no auto-eliminarse', false, 'no lanzó error');
    exception when others then
      v_error := SQLERRM;
      insert into public._remove_player_e2e_results (step, ok, detail)
      values (
        '06 no auto-eliminarse',
        position('cannot_remove_self' in v_error) > 0,
        v_error
      );
    end;

    -- 6) No se puede volver a eliminar a un jugador ya eliminado.
    begin
      perform 1 from public.remove_match_player(v_singles, v_secondary);
      insert into public._remove_player_e2e_results (step, ok, detail)
      values ('07 no reeliminar', false, 'no lanzó error');
    exception when others then
      v_error := SQLERRM;
      insert into public._remove_player_e2e_results (step, ok, detail)
      values (
        '07 no reeliminar',
        position('player_not_removable' in v_error) > 0,
        v_error
      );
    end;

    -- Limpieza.
    delete from public.matches
    where organizer_id in (v_primary, v_secondary)
      and location_name like 'Cancha E2E-RM%';

    if v_friendship_created then
      delete from public.friendships
      where (user_id = v_primary and friend_id = v_secondary)
         or (user_id = v_secondary and friend_id = v_primary);
    end if;
  exception when others then
    execute 'reset role';
    insert into public._remove_player_e2e_results (step, ok, detail)
    values ('ERROR', false, SQLERRM);
  end;

  perform set_config('request.jwt.claim.sub', null, false);
  perform set_config('request.jwt.claims', null, false);
end $$;

select step, ok, detail
from public._remove_player_e2e_results
order by step;

-- La tabla de resultados se elimina al inicio de la próxima ejecución.
-- Para borrarla ahora: drop table if exists public._remove_player_e2e_results;
