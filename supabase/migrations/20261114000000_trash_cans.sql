-- Trash cans as a third kind of user-reported spot (OSM amenity=waste_basket)
-- with the accepted waste in OSM form (waste=trash;cans;plastic_bottles).

alter table public.spots drop constraint spots_category_check;
alter table public.spots add constraint spots_category_check
  check (category in ('smoking', 'toilet', 'bin'));

alter table public.spots add column waste text
  check (waste ~ '^(trash|cans|plastic_bottles)(;(trash|cans|plastic_bottles))*$');

grant insert (waste) on public.spots to authenticated;
grant update (waste) on public.spots to authenticated;
