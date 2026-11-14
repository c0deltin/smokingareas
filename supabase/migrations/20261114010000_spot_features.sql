-- Features of a spot the community can confirm, e.g. "there is a trash can
-- at this smoking area" (OSM bin=yes). Works for every spot – official, OSM
-- and community – keyed by spot id like votes. Append-only; the app uses the
-- latest answer per user (see FeaturePolicy).

create table public.feature_votes (
  id bigint generated always as identity primary key,
  spot_id text not null check (char_length(spot_id) <= 200),
  user_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  feature text not null check (feature in ('bin')),
  value boolean not null,
  created_at timestamptz not null default now()
);

create index feature_votes_spot on public.feature_votes (spot_id);
create index feature_votes_user on public.feature_votes (user_id, created_at);

create trigger feature_votes_rate_limit before insert on public.feature_votes
  for each row execute function public.enforce_rate_limit(60);

alter table public.feature_votes enable row level security;

create policy "feature votes are public" on public.feature_votes
  for select to anon, authenticated using (true);
create policy "vote on features" on public.feature_votes
  for insert to authenticated
  with check (user_id = auth.uid() and public.can_contribute());

revoke insert, update, delete on public.feature_votes from anon, authenticated;
grant insert (spot_id, feature, value) on public.feature_votes to authenticated;

-- Reported smoking areas and toilets can have a trash can.
alter table public.spots add column bin boolean;
grant insert (bin) on public.spots to authenticated;
grant update (bin) on public.spots to authenticated;
