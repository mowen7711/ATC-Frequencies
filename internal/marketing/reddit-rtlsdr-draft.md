# r/RTLSDR draft post (closed-beta framing)

**Title:** Built an Android app that auto-tunes RTL-SDR/SDR Touch to any airport's ATC frequency — looking for one more beta tester

**Body:**

Long-time lurker, built an app over the past few months that I think this sub specifically will get value from.

It's a worldwide ATC frequency lookup (~70,000 airports, tower/ground/approach/etc, sourced from OurAirports) — but the part relevant here: tap a frequency and it fires an `iqsrc://` intent straight into RTL-SDR Driver + SDR Touch, tuned and ready, instead of you typing the MHz in by hand. Also does a VHF line-of-sight reception estimate (4/3 Earth radius model) so you know if a frequency is realistically receivable from where you're sat before you even try.

It's in closed Google Play testing right now and I need one more tester to unlock the next tier — if you've got RTL-SDR + SDR Touch installed and want to kick the tyres, drop a comment or DM and I'll get you a promo code (it's normally £0.99, free for testers). Genuinely just want feedback from people who actually use SDR for this, not generic app reviews.

Opt-in link once you're added: https://play.google.com/apps/testing/com.atcfreq.atc_freq
