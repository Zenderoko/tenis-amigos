-- Eliminar una amistad aceptada y sincronizar la lista en vivo para ambos
-- usuarios. La fila es única por pareja, así que borrarla deja la relación
-- inexistente para las dos partes.

create or replace function public.remove_friend(p_friend_id uuid)
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
  if p_friend_id is null then
    raise exception 'friendship_not_found' using errcode = 'P0002';
  end if;

  select * into v_row
  from public.friendships f
  where (f.user_id = v_user and f.friend_id = p_friend_id)
     or (f.friend_id = v_user and f.user_id = p_friend_id)
  order by f.created_at
  limit 1
  for update;

  if v_row.id is null then
    raise exception 'friendship_not_found' using errcode = 'P0002';
  end if;
  if v_row.status <> 'accepted' then
    raise exception 'friendship_not_accepted' using errcode = 'P0001';
  end if;

  delete from public.friendships where id = v_row.id;
  return query select v_row.id, 'removed'::text;
end;
$$;

revoke all on function public.remove_friend(uuid) from public, anon;
grant execute on function public.remove_friend(uuid) to authenticated;

-- Realtime necesita la fila completa en los DELETE para poder evaluar la RLS
-- (user_id/friend_id) y entregar el evento a las dos personas.
alter table public.friendships replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'friendships'
  ) then
    alter publication supabase_realtime add table public.friendships;
  end if;
end $$;
