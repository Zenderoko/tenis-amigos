-- Amistades: una sola fila por pareja, con solicitudes y respuestas
-- controladas por funciones RPC. El cliente no escribe directamente en la
-- tabla para evitar que alguien se agregue como amigo sin consentimiento.

-- 1) Limpieza e integridad de la tabla.
delete from public.friendships where user_id = friend_id;

with ranked as (
  select
    id,
    row_number() over (
      partition by least(user_id, friend_id), greatest(user_id, friend_id)
      order by
        case status when 'accepted' then 0 when 'pending' then 1 else 2 end,
        created_at
    ) as position
  from public.friendships
)
delete from public.friendships f
using ranked r
where f.id = r.id and r.position > 1;

alter table public.friendships
  drop constraint if exists friendships_no_self;
alter table public.friendships
  add constraint friendships_no_self check (user_id <> friend_id);

create unique index if not exists friendships_pair_unique
  on public.friendships (least(user_id, friend_id), greatest(user_id, friend_id));

create index if not exists friendships_user_id_idx
  on public.friendships (user_id);
create index if not exists friendships_friend_id_idx
  on public.friendships (friend_id);

alter table public.friendships
  add column if not exists responded_at timestamptz;

-- 2) RLS: lectura de las relaciones propias y mutaciones solo por RPC.
drop policy if exists "friendships_insert_own" on public.friendships;
drop policy if exists "friendships_update_own" on public.friendships;
drop policy if exists "friendships_select_own" on public.friendships;
create policy "friendships_select_own" on public.friendships
  for select to authenticated
  using (auth.uid() = user_id or auth.uid() = friend_id);

revoke insert, update, delete on public.friendships from anon, authenticated;

-- 3) El receptor también debe ver el perfil de quien le envía la solicitud.
-- Se conservan las funciones SECURITY DEFINER de la migración anterior para
-- amigos aceptados y participantes de partidos, y se añade el caso pendiente.
drop policy if exists "profiles_select_own_or_related" on public.profiles;
create policy "profiles_select_own_or_related" on public.profiles
  for select to authenticated
  using (
    auth.uid() = id
    or public.are_friends(auth.uid(), id)
    or exists (
      select 1 from public.friendships f
      where f.status = 'pending'
        and (
          (f.user_id = auth.uid() and f.friend_id = profiles.id)
          or (f.friend_id = auth.uid() and f.user_id = profiles.id)
        )
    )
    or public.share_match(auth.uid(), id)
  );

-- 4) Enviar una solicitud por correo exacto.
create or replace function public.send_friend_request_by_email(p_email text)
returns table (friendship_id uuid, status text, target_name text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_target uuid;
  v_name text;
  v_existing public.friendships%rowtype;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_email is null or btrim(p_email) = '' then
    raise exception 'email_required' using errcode = '22023';
  end if;

  select p.id, p.display_name
    into v_target, v_name
  from public.profiles p
  join auth.users u on u.id = p.id
  where lower(u.email) = lower(btrim(p_email))
  limit 1;

  if v_target is null then
    raise exception 'profile_not_found' using errcode = 'P0002';
  end if;
  if v_target = v_user then
    raise exception 'cannot_add_self' using errcode = '22023';
  end if;

  select * into v_existing
  from public.friendships f
  where (f.user_id = v_user and f.friend_id = v_target)
     or (f.user_id = v_target and f.friend_id = v_user)
  order by f.created_at
  limit 1
  for update;

  if v_existing.id is not null then
    if v_existing.status = 'accepted' then
      return query select v_existing.id, 'already_friends'::text, v_name;
      return;
    end if;

    if v_existing.status = 'pending' then
      if v_existing.user_id = v_user then
        return query select v_existing.id, 'already_requested'::text, v_name;
        return;
      else
        update public.friendships
        set status = 'accepted', responded_at = now()
        where id = v_existing.id;
        return query select v_existing.id, 'accepted'::text, v_name;
        return;
      end if;
    end if;

    -- Si la solicitud anterior fue rechazada, se reutiliza la fila.
    update public.friendships
    set user_id = v_user,
        friend_id = v_target,
        status = 'pending',
        created_at = now(),
        responded_at = null
    where id = v_existing.id;
    return query select v_existing.id, 'sent'::text, v_name;
    return;
  end if;

  insert into public.friendships (user_id, friend_id, status)
  values (v_user, v_target, 'pending')
  returning id into v_existing.id;

  return query select v_existing.id, 'sent'::text, v_name;
end;
$$;

revoke all on function public.send_friend_request_by_email(text)
  from public, anon;
grant execute on function public.send_friend_request_by_email(text)
  to authenticated;

-- 5) Aceptar o rechazar una solicitud recibida.
create or replace function public.respond_friend_request(
  p_friendship_id uuid,
  p_accept boolean
)
returns table (friendship_id uuid, status text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_row public.friendships%rowtype;
  v_status text;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select * into v_row
  from public.friendships
  where id = p_friendship_id
  for update;

  if v_row.id is null then
    raise exception 'request_not_found' using errcode = 'P0002';
  end if;
  if v_row.friend_id <> v_user then
    raise exception 'not_request_recipient' using errcode = '42501';
  end if;
  if v_row.status <> 'pending' then
    raise exception 'request_not_pending' using errcode = 'P0001';
  end if;

  v_status := case when p_accept then 'accepted' else 'rejected' end;

  update public.friendships
  set status = v_status, responded_at = now()
  where id = v_row.id;

  return query select v_row.id, v_status;
end;
$$;

revoke all on function public.respond_friend_request(uuid, boolean)
  from public, anon;
grant execute on function public.respond_friend_request(uuid, boolean)
  to authenticated;

-- 6) Cancelar una solicitud enviada.
create or replace function public.cancel_friend_request(p_friendship_id uuid)
returns table (friendship_id uuid, status text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_row public.friendships%rowtype;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select * into v_row
  from public.friendships
  where id = p_friendship_id
  for update;

  if v_row.id is null then
    raise exception 'request_not_found' using errcode = 'P0002';
  end if;
  if v_row.user_id <> v_user then
    raise exception 'not_request_sender' using errcode = '42501';
  end if;
  if v_row.status <> 'pending' then
    raise exception 'request_not_pending' using errcode = 'P0001';
  end if;

  delete from public.friendships where id = v_row.id;
  return query select v_row.id, 'cancelled'::text;
end;
$$;

revoke all on function public.cancel_friend_request(uuid)
  from public, anon;
grant execute on function public.cancel_friend_request(uuid)
  to authenticated;
