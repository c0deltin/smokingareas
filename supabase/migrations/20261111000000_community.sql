-- Community data for smokingareas.
--
-- Everyone (also without login, role `anon`) can read; only signed-in users
-- (Sign in with Apple / Google, role `authenticated`) can contribute, always
-- as themselves (`user_id = auth.uid()`). The moderation rules themselves
-- (ExistencePolicy, ClosurePolicy) are evaluated by the app on these rows;
-- the database guarantees that every row really comes from one account and
-- limits how much one account can write.

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default 'User'
    check (char_length(btrim(display_name)) between 1 and 40),
  -- Set by a moderator (dashboard); banned accounts can no longer write.
  banned boolean not null default false,
  created_at timestamptz not null default now()
);

-- A profile for every new account. Only the first name is used, never the
-- e-mail address.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  full_name text := coalesce(
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'name',
    '');
  first_name text := left(btrim(split_part(btrim(full_name), ' ', 1)), 40);
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(nullif(first_name, ''), 'User'));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- True for signed-in, not banned accounts.
create function public.can_contribute() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and not banned
  );
$$;

-- ---------------------------------------------------------------------------
-- Rate limits (per account and hour)
-- ---------------------------------------------------------------------------

create function public.enforce_rate_limit() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  max_per_hour int := tg_argv[0]::int;
  author_column text := coalesce(tg_argv[1], 'user_id');
  recent int;
begin
  execute format(
    'select count(*) from %I.%I where %I = $1 and created_at > now() - interval ''1 hour''',
    tg_table_schema, tg_table_name, author_column)
  into recent
  using auth.uid();
  if recent >= max_per_hour then
    raise exception 'rate limit exceeded for %', tg_table_name
      using errcode = 'P0429';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Spots reported by users
-- ---------------------------------------------------------------------------

create table public.spots (
  id text primary key default ('community:' || gen_random_uuid()),
  category text not null default 'smoking'
    check (category in ('smoking', 'toilet')),
  -- Japan incl. outlying islands.
  lat double precision not null check (lat between 20 and 46),
  lon double precision not null check (lon between 122 and 154),
  name text not null check (char_length(btrim(name)) between 1 and 80),
  description text check (char_length(description) <= 500),
  indoor boolean,
  covered boolean,
  public_access boolean,
  access_note text check (char_length(access_note) <= 200),
  wheelchair boolean,
  changing_table boolean,
  -- Ids of places the reporter said this is *not* (never merged with them).
  not_same_as text[] not null default '{}'
    check (cardinality(not_same_as) <= 20),
  -- Kept (anonymised) when the account is deleted.
  created_by uuid default auth.uid()
    references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (id like 'community:%')
);

create index spots_position on public.spots (lat, lon);
create index spots_updated on public.spots (updated_at);
create index spots_created_by on public.spots (created_by, created_at);

create trigger spots_rate_limit before insert on public.spots
  for each row execute function public.enforce_rate_limit(10, 'created_by');

create function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger spots_touch before update on public.spots
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Ratings: one per account and spot
-- ---------------------------------------------------------------------------

create table public.reviews (
  spot_id text not null check (char_length(spot_id) <= 200),
  user_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  stars smallint not null check (stars between 1 and 5),
  comment text check (char_length(comment) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (spot_id, user_id)
);

create index reviews_updated on public.reviews (updated_at);
create index reviews_user on public.reviews (user_id, created_at);

create trigger reviews_rate_limit before insert on public.reviews
  for each row execute function public.enforce_rate_limit(60);

create trigger reviews_touch before update on public.reviews
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Photos (files in the storage bucket `spot-photos`, path <user id>/<name>)
-- ---------------------------------------------------------------------------

create table public.photos (
  id uuid primary key default gen_random_uuid(),
  spot_id text not null check (char_length(spot_id) <= 200),
  user_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  storage_path text not null unique,
  created_at timestamptz not null default now(),
  check (storage_path like user_id::text || '/%')
);

create index photos_created on public.photos (created_at);
create index photos_user on public.photos (user_id, created_at);

create trigger photos_rate_limit before insert on public.photos
  for each row execute function public.enforce_rate_limit(20);

-- ---------------------------------------------------------------------------
-- Existence votes and closure reports (append-only history)
-- ---------------------------------------------------------------------------

create table public.votes (
  id bigint generated always as identity primary key,
  spot_id text not null check (char_length(spot_id) <= 200),
  user_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  "exists" boolean not null,
  fingerprint text check (char_length(fingerprint) <= 64),
  created_at timestamptz not null default now()
);

create index votes_spot on public.votes (spot_id);
create index votes_created on public.votes (created_at);
create index votes_user on public.votes (user_id, created_at);

create trigger votes_rate_limit before insert on public.votes
  for each row execute function public.enforce_rate_limit(60);

create table public.closures (
  id bigint generated always as identity primary key,
  spot_id text not null check (char_length(spot_id) <= 200),
  user_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  closed boolean not null,
  note text check (char_length(note) <= 200),
  until timestamptz,
  fingerprint text check (char_length(fingerprint) <= 64),
  created_at timestamptz not null default now(),
  check (until is null or until <= created_at + interval '180 days')
);

create index closures_spot on public.closures (spot_id);
create index closures_created on public.closures (created_at);
create index closures_user on public.closures (user_id, created_at);

create trigger closures_rate_limit before insert on public.closures
  for each row execute function public.enforce_rate_limit(30);

-- ---------------------------------------------------------------------------
-- Moderation: reports of objectionable content and blocked users
-- ---------------------------------------------------------------------------

create table public.content_reports (
  id bigint generated always as identity primary key,
  target_type text not null check (target_type in ('spot', 'review', 'photo', 'user')),
  target_id text not null check (char_length(target_id) <= 200),
  reason text not null check (char_length(btrim(reason)) between 1 and 500),
  user_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create trigger content_reports_rate_limit before insert on public.content_reports
  for each row execute function public.enforce_rate_limit(20);

create table public.blocks (
  user_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, blocked_id),
  check (user_id <> blocked_id)
);

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.spots enable row level security;
alter table public.reviews enable row level security;
alter table public.photos enable row level security;
alter table public.votes enable row level security;
alter table public.closures enable row level security;
alter table public.content_reports enable row level security;
alter table public.blocks enable row level security;

-- Public data: readable by everyone, also without login.
create policy "profiles are public" on public.profiles
  for select to anon, authenticated using (true);
create policy "spots are public" on public.spots
  for select to anon, authenticated using (true);
create policy "reviews are public" on public.reviews
  for select to anon, authenticated using (true);
create policy "photos are public" on public.photos
  for select to anon, authenticated using (true);
create policy "votes are public" on public.votes
  for select to anon, authenticated using (true);
create policy "closures are public" on public.closures
  for select to anon, authenticated using (true);

-- Own profile: only the display name can change.
create policy "rename own profile" on public.profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Contributions: always as oneself, never when banned.
create policy "report spots" on public.spots
  for insert to authenticated
  with check (created_by = auth.uid() and public.can_contribute());
create policy "edit own spots" on public.spots
  for update to authenticated
  using (created_by = auth.uid() and public.can_contribute())
  with check (created_by = auth.uid());
create policy "delete own spots" on public.spots
  for delete to authenticated using (created_by = auth.uid());

create policy "rate" on public.reviews
  for insert to authenticated
  with check (user_id = auth.uid() and public.can_contribute());
create policy "change own rating" on public.reviews
  for update to authenticated
  using (user_id = auth.uid() and public.can_contribute())
  with check (user_id = auth.uid());
create policy "delete own rating" on public.reviews
  for delete to authenticated using (user_id = auth.uid());

create policy "add photos" on public.photos
  for insert to authenticated
  with check (user_id = auth.uid() and public.can_contribute());
create policy "delete own photos" on public.photos
  for delete to authenticated using (user_id = auth.uid());

create policy "vote" on public.votes
  for insert to authenticated
  with check (user_id = auth.uid() and public.can_contribute());

create policy "report closures" on public.closures
  for insert to authenticated
  with check (user_id = auth.uid() and public.can_contribute());

-- Content reports are write-only for users (moderators use the dashboard).
create policy "report content" on public.content_reports
  for insert to authenticated with check (user_id = auth.uid());

-- Blocks are private.
create policy "see own blocks" on public.blocks
  for select to authenticated using (user_id = auth.uid());
create policy "block users" on public.blocks
  for insert to authenticated with check (user_id = auth.uid());
create policy "unblock users" on public.blocks
  for delete to authenticated using (user_id = auth.uid());

-- Columns users may never set themselves (author and timestamps come from
-- the database, so rate limits cannot be bypassed).
revoke insert on public.spots, public.reviews, public.photos, public.votes,
  public.closures, public.content_reports, public.blocks, public.profiles
  from anon, authenticated;
grant insert (id, category, lat, lon, name, description, indoor, covered,
  public_access, access_note, wheelchair, changing_table, not_same_as)
  on public.spots to authenticated;
grant insert (spot_id, stars, comment) on public.reviews to authenticated;
grant insert (id, spot_id, storage_path) on public.photos to authenticated;
grant insert (spot_id, "exists", fingerprint) on public.votes to authenticated;
grant insert (spot_id, closed, note, until, fingerprint)
  on public.closures to authenticated;
grant insert (target_type, target_id, reason)
  on public.content_reports to authenticated;
grant insert (blocked_id) on public.blocks to authenticated;
revoke update on public.profiles from anon, authenticated;
grant update (display_name) on public.profiles to authenticated;
revoke update on public.spots from anon, authenticated;
grant update (name, description, indoor, covered, public_access, access_note,
  wheelchair, changing_table) on public.spots to authenticated;
revoke update on public.reviews from anon, authenticated;
-- spot_id: PostgREST upserts set every sent column.
grant update (spot_id, stars, comment) on public.reviews to authenticated;

-- ---------------------------------------------------------------------------
-- Account deletion (required by the App Store): removes the account and all
-- its ratings, photos rows, votes, closure reports and blocks; reported
-- spots stay on the map without author. The app deletes the photo files
-- (storage API) before calling this.
-- ---------------------------------------------------------------------------

create function public.delete_account() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;

-- Internal helpers are not part of the API.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.enforce_rate_limit() from public, anon, authenticated;
revoke execute on function public.touch_updated_at() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Photo files: public bucket, max. 2 MB JPEG, uploads only into the own
-- folder (<user id>/…).
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('spot-photos', 'spot-photos', true, 2097152, array['image/jpeg']);

create policy "upload own photos" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'spot-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.can_contribute()
  );

create policy "delete own photo files" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'spot-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
