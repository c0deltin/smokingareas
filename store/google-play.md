# Google Play (Android)

Everything for the Play Console. Same positioning as the App Store: help to
follow smoking rules and find toilets – never promote tobacco (Google Play
policy on tobacco: no sale or promotion).

## Before the listing

- Developer account (one-time fee) with identity verification.
- New personal developer accounts must run a **closed test with at least 12
  testers for 14 days** before production access.
- Upload format: Android App Bundle (AAB). The release workflow currently
  builds an APK; an AAB build and upload step is added when the Play Store
  is chosen.
- Play App Signing: Google keeps the app signing key; our existing release
  key becomes the upload key.

## Store listing

**App name [30]:** Ippuku (search terms such as "smoking area" go into the
descriptions; Google Play has no keyword field)

**Short description [80]:**
EN: Designated smoking areas and public toilets in 54 Japanese cities.
JA: 日本54都市の指定喫煙所と公衆トイレを地図で表示。
DE: Ausgewiesene Raucherbereiche und Toiletten in 54 Städten Japans.

**Full description [4000]:** use the App Store descriptions in
`app-store.md` (English, Japanese, German) unchanged.

**Category:** Travel & Local. **Tags:** Travel guide, Maps.
**Contact:** e-mail [CONTACT E-MAIL], website
https://c0deltin.github.io/smokingareas/, privacy policy
https://c0deltin.github.io/smokingareas/privacy/.

**Graphics:** icon 512 × 512 (`assets/icon/icon.png` scaled), feature
graphic 1024 × 500, 2–8 phone screenshots (same scenes as for the App
Store).

## App content

### Privacy policy
https://c0deltin.github.io/smokingareas/privacy/

### Ads
No ads.

### App access
"All functionality is available without special access." (Map without
account; community features with Google Sign-In – any Google account
works.)

### Content rating (IARC questionnaire)
- Category: Reference, News or Educational? → **No**, choose "All other app
  types".
- Violence, sexuality, language, gambling: **No**.
- Controlled substances: **references to tobacco – yes** (the app shows
  designated smoking areas; no sale or promotion).
- User interaction: **users can interact / share user-generated content –
  yes** (moderated, report and block available).
- Shares the user's location with other users: **No**.

### Target audience
18 and older only.

### Data safety

Data collected (all **required for app functionality**, encrypted in
transit, users can request deletion):

| Data type | Collected | Shared | Optional | Purpose |
|---|---|---|---|---|
| Personal info → Name | Yes | No | Yes (only with an account) | App functionality, account management |
| Personal info → Email address | Yes | No | Yes | Account management |
| Personal info → User IDs | Yes | No | Yes | Account management |
| Photos and videos → Photos | Yes | No | Yes | App functionality |
| App activity → Other user-generated content | Yes | No | Yes | App functionality (places, ratings, comments, reports) |

**Not collected:** Location (processed only on the device), app info and
performance, device IDs, financial info, messages, contacts, web history.

Shared with third parties: **No** (the backend host and Google Maps are
processors acting on our behalf, which Google does not count as sharing).
Also check the Google Maps SDK's own disclosure for Android and add what
Google states for it.

Data deletion: users can delete their account in the app; web page for
deletion requests: https://c0deltin.github.io/smokingareas/delete-account/

### Location permissions (background location declaration)

**Feature that uses background location:**
> Optional proximity alert: when the user turns on alerts, the app notifies
> them when they come close to a designated smoking area, so they can follow
> local smoking bans. The radius is set by the user (10–150 m).

**Why foreground-only access is not enough:**
> Users walk around with the phone in their pocket; the alert is only
> useful when the app is not open. A persistent notification is shown while
> alerts are on, and users can turn them off at any time.

**Prominent disclosure** (shown in the app before the permission request –
implemented in `lib/ui/location_disclosure.dart`):
> "Ippuku uses your location to show nearby smoking areas and public
> toilets on the map. If you turn on alerts, the app also uses your location
> in the background – even when the app is closed or not in use – to notify
> you when you are close to a designated smoking area. Your location is
> processed only on your device …"

**Video (30 s, upload to YouTube as unlisted):**
1. Open the app – the disclosure dialog appears; tap "Continue".
2. Grant location "While using the app", then "Allow all the time" in the
   settings page the app opens.
3. Tap the bell to turn alerts on – the persistent notification appears.
4. Close the app, walk (or simulate a location) near a smoking area – the
   alert notification appears.

### Foreground service declaration
Type **location**: "Shows the persistent notification while proximity
alerts are on and keeps location updates running for the alert."

### Health, financial, government, news
Not applicable.

## Closed test (12 testers, 14 days)

1. Create a Google Group or an e-mail list with at least 12 testers.
2. Play Console → Testing → Closed testing → create a track, add the
   testers, upload the AAB, roll out.
3. Testers join via the opt-in link and keep the app installed for 14 days.
4. Then apply for production access (questions about the test and the app).
