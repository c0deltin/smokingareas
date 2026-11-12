# Publishing checklist

Texts and answers for the stores are prepared in this folder:

- [`app-store.md`](app-store.md) – App Store Connect: listing (EN/JA/DE),
  App Privacy answers, age rating, review notes, screenshots.
- [`google-play.md`](google-play.md) – Play Console: listing, content
  rating, data safety, background location declaration with video script,
  closed test.

## Before submitting

- [ ] Legal pages: fill in the `[PLACEHOLDERS]` in `docs/`, have them
      checked, enable GitHub Pages (Settings → Pages → `main` / `/docs`).
- [ ] Backend on a paid plan (free projects pause after a week without
      traffic and have no backups).
- [ ] Google Maps Android key restricted to the package and release SHA-1.
- [ ] Device tests: Google sign-in (iOS + Android), background alerts and
      radius, direction cone, camera/photos, map performance in Tokyo.
- [ ] Japanese texts checked by a native speaker.
- [ ] Screenshots taken (6.9" iPhone; Android phone).
- [ ] Moderation routine: check `content_reports` daily (Apple expects
      reports to be handled within 24 hours).

## App Store

- [ ] App information, pricing (free), availability.
- [ ] Listing texts for English, Japanese and German.
- [ ] App Privacy and age rating as in `app-store.md`.
- [ ] App Review notes and contact.
- [ ] Select the TestFlight build and submit for review.

## Google Play (if chosen)

- [ ] Developer account and identity verification.
- [ ] AAB build and upload in the release workflow (to be added).
- [ ] App content forms as in `google-play.md`, including the background
      location video.
- [ ] Closed test with 12 testers for 14 days, then production access.
