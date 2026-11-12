-- Tests for the community schema: run on a fresh PostgreSQL after
-- supabase_stub.sql and all migrations (see run_tests.sh).
\set ON_ERROR_STOP on
set client_min_messages = warning;

create schema tests;
grant usage on schema tests to anon, authenticated;

-- Fails unless [stmt] raises an error whose message contains [expected].
create function tests.expect_error(stmt text, expected text) returns void
language plpgsql as $$
begin
  execute stmt;
  raise exception 'expected error "%" for: %', expected, stmt;
exception when others then
  if sqlerrm not like '%' || expected || '%' then
    raise exception 'expected "%", got "%" for: %', expected, sqlerrm, stmt;
  end if;
end;
$$;

create function tests.expect(ok boolean, what text) returns void
language plpgsql as $$
begin
  if not coalesce(ok, false) then
    raise exception 'failed: %', what;
  end if;
end;
$$;
grant execute on all functions in schema tests to anon, authenticated;

-- Two accounts, as created by Sign in with Apple / Google.
insert into auth.users (id, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', '{"full_name": "Aiko Tanaka"}'),
  ('22222222-2222-2222-2222-222222222222', '{}');

select tests.expect(
  (select display_name from profiles
   where id = '11111111-1111-1111-1111-111111111111') = 'Aiko',
  'profile uses only the first name');
select tests.expect(
  (select display_name from profiles
   where id = '22222222-2222-2222-2222-222222222222') = 'User',
  'profile without name');

-- ---------------------------------------------------------------- anon
set role anon;
select set_config('request.jwt.claims', '', false);

select tests.expect((select count(*) from profiles) = 2, 'anon reads profiles');
select tests.expect_error(
  $$insert into votes (spot_id, "exists") values ('osm:node/1', false)$$,
  'permission denied');
select tests.expect_error(
  $$insert into spots (lat, lon, name) values (35.69, 139.70, 'X')$$,
  'permission denied');
select tests.expect_error($$select delete_account()$$, 'permission denied');
reset role;

-- ---------------------------------------------------------------- user 1
set role authenticated;
select set_config('request.jwt.claims',
  '{"sub": "11111111-1111-1111-1111-111111111111"}', false);

insert into spots (lat, lon, name, category)
  values (35.6900, 139.7000, 'Behind the station', 'smoking');
select tests.expect(
  (select created_by from spots) = '11111111-1111-1111-1111-111111111111'
  and (select id from spots) like 'community:%',
  'spot gets the author and a community id');

-- Author and timestamps cannot be chosen by the client.
select tests.expect_error(
  $$insert into spots (lat, lon, name, created_by)
    values (35.69, 139.70, 'Fake', '22222222-2222-2222-2222-222222222222')$$,
  'permission denied');
select tests.expect_error(
  $$insert into votes (spot_id, "exists", created_at)
    values ('osm:node/1', false, now() - interval '2 hours')$$,
  'permission denied');
select tests.expect_error(
  $$insert into spots (lat, lon, name) values (48.1, 11.5, 'Munich')$$,
  'spots_lat_check');
select tests.expect_error(
  $$insert into spots (id, lat, lon, name) values ('osm:node/9', 35.69, 139.70, 'Hijack')$$,
  'spots_id_check');

-- One rating per account and spot; upsert replaces it.
insert into reviews (spot_id, stars) values ('osm:node/1', 4);
insert into reviews (spot_id, stars, comment) values ('osm:node/1', 2, 'Dirty')
  on conflict (spot_id, user_id)
  do update set spot_id = excluded.spot_id, stars = excluded.stars,
    comment = excluded.comment;
select tests.expect(
  (select count(*) from reviews) = 1 and (select stars from reviews) = 2,
  'second rating replaces the first');
select tests.expect_error(
  $$insert into reviews (spot_id, stars) values ('osm:node/2', 6)$$,
  'reviews_stars_check');

insert into votes (spot_id, "exists", fingerprint)
  values ('osm:node/1', false, 'abc123');
insert into closures (spot_id, closed, note, until)
  values ('osm:node/1', true, 'Construction', now() + interval '30 days');
select tests.expect_error(
  $$insert into closures (spot_id, closed, until)
    values ('osm:node/1', true, now() + interval '1 year')$$,
  'closures_check');

-- Votes are history: no update, no delete.
update votes set "exists" = true;
delete from votes;
select tests.expect((select count(*) from votes) = 1, 'votes are append-only');

-- Photos only in the own folder.
insert into photos (spot_id, storage_path)
  values ('osm:node/1', '11111111-1111-1111-1111-111111111111/a.jpg');
select tests.expect_error(
  $$insert into photos (spot_id, storage_path)
    values ('osm:node/1', '22222222-2222-2222-2222-222222222222/b.jpg')$$,
  'photos_check');
insert into storage.objects (bucket_id, name)
  values ('spot-photos', '11111111-1111-1111-1111-111111111111/a.jpg');
select tests.expect_error(
  $$insert into storage.objects (bucket_id, name)
    values ('spot-photos', '22222222-2222-2222-2222-222222222222/x.jpg')$$,
  'row-level security');

-- Photo files can be read by everyone (also needed for uploads).
reset role;
set role anon;
select tests.expect(
  (select count(*) from storage.objects where bucket_id = 'spot-photos') = 1,
  'photo files are readable without login');
reset role;
set role authenticated;
select set_config('request.jwt.claims',
  '{"sub": "11111111-1111-1111-1111-111111111111"}', false);

-- Profile: only the own display name.
update profiles set display_name = 'Aiko T.';
select tests.expect(
  (select count(*) from profiles where display_name = 'Aiko T.') = 1,
  'rename only changes the own profile');
select tests.expect_error(
  $$update profiles set banned = false$$, 'permission denied');

-- Moderation: report content, block a user.
insert into content_reports (target_type, target_id, reason)
  values ('review', 'osm:node/1', 'Spam');
select tests.expect((select count(*) from content_reports) = 0,
  'content reports are not readable by users');
insert into blocks (blocked_id) values ('22222222-2222-2222-2222-222222222222');
reset role;

-- ---------------------------------------------------------------- user 2
set role authenticated;
select set_config('request.jwt.claims',
  '{"sub": "22222222-2222-2222-2222-222222222222"}', false);

update spots set name = 'Vandalised';
delete from spots;
update reviews set stars = 5;
select tests.expect(
  (select name from spots) = 'Behind the station'
  and (select stars from reviews) = 2,
  'other users cannot change foreign rows');
select tests.expect((select count(*) from blocks) = 0, 'blocks are private');

-- Rate limit: at most 60 votes per hour.
do $$
begin
  for i in 1..60 loop
    insert into votes (spot_id, "exists") values ('osm:node/' || i, true);
  end loop;
end;
$$;
select tests.expect_error(
  $$insert into votes (spot_id, "exists") values ('osm:node/61', true)$$,
  'rate limit exceeded');
reset role;

-- Banned accounts can no longer contribute.
update profiles set banned = true where id = '22222222-2222-2222-2222-222222222222';
set role authenticated;
select tests.expect_error(
  $$insert into reviews (spot_id, stars) values ('osm:node/3', 5)$$,
  'row-level security');
reset role;

-- ---------------------------------------------------------------- deletion
set role authenticated;
select set_config('request.jwt.claims',
  '{"sub": "11111111-1111-1111-1111-111111111111"}', false);
select delete_account();
reset role;

select tests.expect(
  (select count(*) from profiles where id = '11111111-1111-1111-1111-111111111111') = 0
  and (select count(*) from reviews) = 0
  and (select count(*) from photos) = 0
  and (select count(*) from closures) = 0
  and (select count(*) from votes where user_id = '11111111-1111-1111-1111-111111111111') = 0,
  'account deletion removes the user''s contributions');
select tests.expect(
  (select count(*) from spots) = 1 and (select created_by from spots) is null,
  'reported spots stay, without author');

\echo 'All database tests passed.'
