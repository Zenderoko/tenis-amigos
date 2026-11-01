-- Normaliza los valores de perfil y prepara Storage para las fotos.
-- Los niveles y la mano dominante usan claves estables en inglés; la app
-- muestra las etiquetas en español.

update public.profiles
set tennis_level = case lower(trim(tennis_level))
  when 'beginner' then 'beginner'
  when 'principiante' then 'beginner'
  when 'iniciación' then 'beginner'
  when 'iniciacion' then 'beginner'
  when 'intermediate' then 'intermediate'
  when 'intermedio' then 'intermediate'
  when 'advanced' then 'advanced'
  when 'avanzado' then 'advanced'
  when 'competitive' then 'competitive'
  when 'competitivo' then 'competitive'
  else null
end
where tennis_level is not null;

update public.profiles
set dominant_hand = case lower(trim(dominant_hand))
  when 'right' then 'right'
  when 'diestro' then 'right'
  when 'derecha' then 'right'
  when 'left' then 'left'
  when 'zurdo' then 'left'
  when 'izquierda' then 'left'
  else null
end
where dominant_hand is not null;

alter table public.profiles
  drop constraint if exists profiles_tennis_level_check;
alter table public.profiles
  add constraint profiles_tennis_level_check
  check (
    tennis_level is null
    or tennis_level in ('beginner', 'intermediate', 'advanced', 'competitive')
  );

alter table public.profiles
  drop constraint if exists profiles_dominant_hand_check;
alter table public.profiles
  add constraint profiles_dominant_hand_check
  check (dominant_hand is null or dominant_hand in ('right', 'left'));

-- Bucket público para leer las fotos por URL y escritura limitada al dueño.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
