# ATC Frequencies — Marketing Strategy

Status: app is in **closed testing** (11/12 testers). This plan has two phases — don't skip Phase 0.

## Phase 0 — unblock distribution (do this first)
- Get the 12th closed tester (post the opt-in link in 1-2 low-effort spots below) to unlock the next Play Console tier.
- Move to **open testing** (no cap, public opt-in link, still shows "Early access" badge) as soon as the tier allows — this is the real prerequisite for any organic push, since open testing links are postable anywhere without gatekeeping via the Google Group.
- Production release is the trigger for any paid spend or press outreach — don't burn either before then.

## Phase 1 — zero-budget organic (current focus)
Target audience: pilots (PPL/student), plane spotters, ATC/radio scanner hobbyists, RTL-SDR/SDR Touch users, flight sim users who also fly real radios.

**Channels, in priority order:**
1. **r/RTLSDR** and **r/flightradar24** / **r/aviation** / **r/flying** / **r/PlaneSpotting** — the SDR auto-tune integration (`iqsrc://` direct tune from a frequency card) is a genuine, rare differentiator. Lead with that, not the airport database (every competitor has a database).
2. **PPRuNe / FlyerForums** (UK pilot forums) — Mark is UK-based, app has UK relevance; "tools" or "apps" subforum threads.
3. **Plane-spotting & ATC-listening YouTube/TikTok creators** — short outreach offering a free promo code, not a sponsorship ask.
4. **LiveATC.net community** — app links out to LiveATC; their forum/Discord is a natural fit for cross-promotion (ask permission, don't spam).
5. **ASO** — Play Store title/description keyword pass (see below) costs nothing and compounds.

## ASO pass (do this regardless of testing tier)
- Title: keep "ATC Frequencies" — already keyword-matched to the #1 search term.
- Short description candidates (80 char limit), pick one:
  - "70,000+ airport ATC frequencies, live audio links, and SDR auto-tune."
  - "Find any airport's tower, ground & approach frequencies worldwide."
- Long description should front-load: airport count, ICAO/IATA/city search, nearby-via-GPS, LiveATC link-out, SDR direct-tune, VHF reception calculator, persistent nearest-airport notification. In that order — most-searched terms first.
- Use existing assets in `docs/`: `feature-graphic.png` (1024x500) and `ss1-4-cropped.jpeg` are ready for the listing; no new creative needed yet.

## Phase 2 — once in open/production (do not start before)
- Public Reddit/forum posts swap "join the beta" framing for a direct Play Store link.
- Consider a small paid trial ($20-50) on Reddit Ads targeted at r/aviation-adjacent interests, only after organic CTR/conversion is validated.
- Reach out to aviation press/blogs (Simple Flying, AVweb, PPRuNe news desk) with a short pitch once there's an install/rating count worth citing — don't pitch a 0-review app.

## Guardrails
- Never claim FAA/regulatory endorsement — this is an unofficial reference tool.
- Never fabricate reviews, ratings, or install numbers in copy.
- Don't promise features not in `CLAUDE.md`.
- Track every post/DM sent in `internal/marketing/outreach-log.md` (create on first use) to avoid duplicate or spammy re-posting across subreddits/forums.

## Next action right now
Post the closed-testing opt-in link (`https://play.google.com/apps/testing/com.atcfreq.atc_freq`) to get tester #12, using the r/RTLSDR draft in `internal/marketing/reddit-rtlsdr-draft.md`.
