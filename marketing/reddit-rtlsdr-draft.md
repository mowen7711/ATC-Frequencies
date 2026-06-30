---
channel: r/RTLSDR
type: Reddit post
status: Drafted
date: 2026-06-30
---

# r/RTLSDR — Auto-tune ATC frequencies directly into SDR Touch

**Title:** Built an Android app that pulls up any airport's ATC frequency and auto-tunes RTL-SDR/SDR Touch with one tap

**Body:**

Long-time lurker, built an app over the past few months that I think this sub specifically will get value from.

It's a worldwide ATC frequency lookup (~70,000 airports, tower/ground/approach/etc, sourced from OurAirports) — but the part relevant here: tap a frequency and it fires an `iqsrc://` intent straight into RTL-SDR Driver + SDR Touch, tuned and ready, instead of typing the MHz in by hand. Also does a VHF line-of-sight reception estimate (4/3 Earth radius model) so you know if a frequency is realistically receivable from where you're sat before you even try.

It's £0.99 on the Play Store: https://play.google.com/store/apps/details?id=com.atcfreq.atc_freq

Happy to answer questions about the SDR integration if anyone's curious how the `iqsrc://` intent handoff works.
