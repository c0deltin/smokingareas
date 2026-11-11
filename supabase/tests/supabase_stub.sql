-- Minimal stand-in for the parts of a Supabase database the migrations use
-- (roles, auth.users, auth.uid(), storage), so they can be tested on a plain
-- PostgreSQL. Not used in production.

-- Roles are cluster-wide, so create them only once.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
    create role authenticated nologin;
    create role service_role nologin bypassrls;
  end if;
end;
$$;

create schema auth;
create table auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  raw_user_meta_data jsonb not null default '{}'
);

-- Like Supabase: the user id from the JWT claims of the request.
create function auth.uid() returns uuid language sql stable as $$
  select nullif(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub',
    '')::uuid
$$;

create schema storage;
create table storage.buckets (
  id text primary key,
  name text not null,
  public boolean default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);
create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets (id),
  name text,
  owner uuid default auth.uid()
);
alter table storage.objects enable row level security;
create function storage.foldername(name text) returns text[]
language sql immutable as $$
  select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1]
$$;

grant usage on schema public, auth, storage to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated;
grant execute on function storage.foldername(text) to anon, authenticated;
grant select, insert, update, delete on storage.objects to anon, authenticated;

-- Supabase grants the API roles everything on new public tables; RLS and
-- the migrations' column grants restrict it.
alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public
  grant execute on functions to anon, authenticated, service_role;
