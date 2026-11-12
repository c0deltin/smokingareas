-- Photo files are public, but reading them through the storage API (and
-- uploading, which returns the new row) needs a SELECT policy on
-- storage.objects; without it uploads failed and other devices could not
-- download photos.
create policy "photo files are public" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'spot-photos');
