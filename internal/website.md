# ATC Frequencies — Website Documentation

**Live URL:** https://atc-frequencies.app
**Hosting:** Self-hosted on existing Hetzner Cloud server, behind Cloudflare
**Source:** `docs/` directory in this repo (single static HTML file, no build step)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Domain & DNS](#3-domain--dns)
4. [TLS / Certificates](#4-tls--certificates)
5. [Server](#5-server)
6. [nginx Configuration](#6-nginx-configuration)
7. [Firewall](#7-firewall)
8. [Site Contents & Deployment](#8-site-contents--deployment)
9. [Website Analytics](#9-website-analytics)
10. [SEO](#10-seo)
11. [Pricing](#11-pricing)
12. [Known Gotchas](#12-known-gotchas)
13. [Runbook — Common Tasks](#13-runbook--common-tasks)

---

## 1. Overview

The marketing/landing page for ATC Frequencies is a single self-contained `docs/index.html` file — no framework, no build step, inline CSS/JS. It was originally built to also serve as the GitHub Pages source (`docs/` is still the Pages root for `mowen7711.github.io/ATC-Frequencies/`), and was later additionally deployed to a dedicated domain (`atc-frequencies.app`) on infrastructure the developer already controls, fronted by Cloudflare.

Design: dark theme matching the app's colour palette (`#0B1120` background, `#FFB300` accent), animated hero (radar pulse arcs, ATC tower silhouette, drifting clouds), custom cursor, 3D tilt on cards, magnetic buttons, scroll-reveal sections, live phone-framed screenshots, and a VHF signal reception "spotlight" section with an explicit calculation-not-guarantee disclaimer.

## 2. Architecture

```
Visitor
  │ HTTPS
  ▼
Cloudflare (proxied, orange cloud)
  │ HTTPS (Full strict — validates origin cert)
  ▼
nginx on 4t-tech-ubnt-01 (Hetzner Cloud server)
  │
  ├─ atc-frequencies.app          → /var/www/atcfrequencies (this site)
  ├─ www.atc-frequencies.app      → 301 redirect to apex
  ├─ existing "default" vhost     → stock nginx page, unused, untouched
  └─ existing "prometheus" vhost  → proxies to a different Tailscale node, untouched

Client-side beacon (page_view / cta_click / scroll_depth)
  │ HTTPS POST
  ▼
Cloudflare Worker — atc-freq-metrics.mark-78f.workers.dev (same one the app uses)
  │ UNNEST INSERT
  ▼
NeonDB atc_metrics table ◄── Grafana (grafana/website.json)
```

The same physical server also runs a **Unifi Network Controller** (Java, ports 8443/8843/8880/8080/6789/28082, backed by a local MongoDB) and is reachable for SSH **only via Tailscale**, not the public internet. None of the website work touches either of those.

## 3. Domain & DNS

- Registered at **IONOS**: `atc-frequencies.app`
- `.app` is on Chrome's HSTS preload list — HTTPS is mandatory from the very first request, no plain-HTTP grace period. IONOS's "you need an SSL cert" warning at checkout was for their own hosting product; it doesn't apply since DNS points to Cloudflare instead.
- Nameservers at IONOS changed to Cloudflare's assigned pair (`roan.ns.cloudflare.com`, `grace.ns.cloudflare.com`)
- DNS records in Cloudflare (zone: `atc-frequencies.app`):
  | Type | Name | Value | Proxy |
  |------|------|-------|-------|
  | A | `@` | `46.62.240.112` | Proxied |
  | A | `www` | `46.62.240.112` | Proxied |
- Cloudflare SSL/TLS mode: **Full (strict)**

## 4. TLS / Certificates

Using a **Cloudflare Origin Certificate** (not Let's Encrypt) — simpler than Let's Encrypt here because Cloudflare proxies (orange cloud) everything, which would otherwise break Let's Encrypt's HTTP-01 challenge (it'd need to un-proxy on every renewal). The Origin Certificate is 15-year-valid and Cloudflare-trusted by design.

- Created in Cloudflare dashboard: zone → SSL/TLS → Origin Server → Create Certificate
- Hostnames covered: `atc-frequencies.app`, `*.atc-frequencies.app`
- Installed on the server at:
  - `/etc/ssl/cloudflare/origin.pem` (644, world-readable cert)
  - `/etc/ssl/cloudflare/origin.key` (600, root-only — **never** committed to git or any password manager isn't needed either; if lost, just regenerate a new one in the dashboard)
- Validity: 2026-06-29 → 2041-06-25

There's a second, older, unrelated Let's Encrypt cert on this server for `4t-tech-ubnt-01.4t-technologies.com` (`/etc/letsencrypt/live/...`) — pre-existing, used by something else, not touched.

## 5. Server

- **Hostname:** `4t-tech-ubnt-01`
- **Public IP:** `46.62.240.112` (Hetzner Cloud)
- **Tailscale IP:** `100.103.65.20` — SSH (`root@100.103.65.20`) only works over Tailscale; sshd is not bound to the public interface at all (`ss -tlnp` shows it listening on the Tailscale IP only). This means firewall changes to the public interface can never lock out SSH access.
- **OS:** Ubuntu 24.04.4 LTS
- **Other services on this box:** Unifi Network Controller + MongoDB (pre-existing, unrelated)
- **Access:** Hetzner Cloud Console (web-based serial console, no network needed) is the fallback if Tailscale or SSH ever break.

## 6. nginx Configuration

File: `/etc/nginx/sites-available/atcfrequencies` (symlinked into `sites-enabled/`)

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name atc-frequencies.app www.atc-frequencies.app;
    return 301 https://atc-frequencies.app$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name www.atc-frequencies.app;

    ssl_certificate     /etc/ssl/cloudflare/origin.pem;
    ssl_certificate_key /etc/ssl/cloudflare/origin.key;

    return 301 https://atc-frequencies.app$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name atc-frequencies.app;

    ssl_certificate     /etc/ssl/cloudflare/origin.pem;
    ssl_certificate_key /etc/ssl/cloudflare/origin.key;

    root /var/www/atcfrequencies;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

Both HTTP and the `www` host 301-redirect to the canonical `https://atc-frequencies.app` — one canonical URL for SEO, avoiding duplicate-content dilution between `www` and apex.

Reload after any config change: `nginx -t && systemctl reload nginx`

## 7. Firewall

`ufw` on the server, default-deny incoming / default-allow outgoing. Rule groups:

| Purpose | Rule |
|---------|------|
| Tailscale tunnel (covers SSH) | `ufw allow in on tailscale0` |
| Tailscale direct/NAT-traversal transport | `ufw allow 41641/udp` |
| Unifi controller (reachable from internet — some devices check in remotely) | `8443/tcp`, `8843/tcp`, `8880/tcp`, `8080/tcp`, `6789/tcp`, `28082/tcp`, `3478/udp`, `10001/udp`, `5514/udp` — all "Anywhere" |
| Website (80, 443) | Allowed **only** from Cloudflare's published IPv4/IPv6 ranges (`https://www.cloudflare.com/ips-v4` / `ips-v6`) |

Direct requests to `46.62.240.112:443` bypassing Cloudflare are refused at the firewall (`connection refused`, confirmed via `curl --resolve`).

**Maintenance:** Cloudflare's IP ranges change occasionally. Re-fetch and re-apply periodically:

```bash
ssh root@100.103.65.20
for ip in $(curl -s https://www.cloudflare.com/ips-v4); do ufw allow from $ip to any port 80,443 proto tcp; done
for ip in $(curl -s https://www.cloudflare.com/ips-v6); do ufw allow from $ip to any port 80,443 proto tcp; done
```

Old rules for stale IPs aren't auto-removed — periodically review `ufw status numbered` and prune.

**Known gotcha hit during setup:** there was a pre-existing blanket `443/tcp ALLOW Anywhere` rule (both v4 and v6) left over from before this work, which silently defeated the Cloudflare-only restriction. Deleted via `ufw delete <number>`. If direct-IP access to the site ever works again unexpectedly, check `ufw status numbered` for a stray broad rule like this.

**Not yet done:** mirroring this same Cloudflare-only restriction in the **Hetzner Cloud Firewall** (Cloud Console → server → Firewalls) as defense-in-depth, in case `ufw` is ever disabled/reset.

## 8. Site Contents & Deployment

Everything lives in `docs/`, but **only specific files are deployed** to the server — `docs/` also contains files that are not meant to be public (dev preview pages, unused image variants) and historically contained internal business documents (moved out to `internal/`, see Section 12).

**Files actually served** (`/var/www/atcfrequencies/` on the server):
```
index.html
privacy-policy.html
robots.txt
sitemap.xml
feature-graphic-1024x500.jpg   (used as the OG/Twitter social preview image)
ss1-cropped.jpeg … ss4-cropped.jpeg   (screenshot gallery)
img/icon.svg                  (favicon + hero/footer logo)
img/icon-512.png              (apple-touch-icon)
```

**Deploy command** (run from the repo root on the dev Mac):
```bash
rsync -avz -e ssh \
  docs/index.html docs/privacy-policy.html docs/robots.txt docs/sitemap.xml \
  docs/ss1-cropped.jpeg docs/ss2-cropped.jpeg docs/ss3-cropped.jpeg docs/ss4-cropped.jpeg \
  docs/feature-graphic-1024x500.jpg \
  root@100.103.65.20:/var/www/atcfrequencies/
rsync -avz -e ssh docs/img/icon.svg docs/img/icon-512.png root@100.103.65.20:/var/www/atcfrequencies/img/
```
No nginx reload needed for static file changes — only after editing the nginx config itself.

**Do not** `rsync -avz --delete docs/ root@...:/var/www/atcfrequencies/` (mirroring the whole folder) — this was the original mistake during setup; it pulled `marketing-strategy.md`, the `marketing/` folder, and dev preview HTML onto the public web server. Always deploy an explicit file list, as above.

## 9. Website Analytics

Reuses the app's existing pipeline rather than adding a third-party tracker — same Cloudflare Worker (`metrics-relay/index.js`), same NeonDB `atc_metrics` table, distinguished by measurement name.

**Worker change:** added `web_event` to `VALID_MEASUREMENTS`, and extended the geo-tagging logic (previously only `app_event`/`app_open`) to also tag `web_event`/`page_view` with Cloudflare-derived country/city.

**Client-side beacon** (inline `<script>` at the bottom of `docs/index.html`):
- Anonymous per-browser ID: `crypto.randomUUID()`, stored in `localStorage` (`atc_web_metrics_id`) — not a cookie
- `page_view` — fired once on load, tagged with `path`
- `cta_click` — fired on click of any `.nav-cta`, `.play-link`, `.btn-primary`, `.btn-ghost` link, tagged with a `target` name (`nav_get_app`, `cta_play_store`, `hero_play_store`, `hero_explore_features`)
- `scroll_depth` — fired once per milestone (25/50/75/100%) per page load
- `page_view` also carries `referrer_source` (e.g. `google.com`, `reddit.com`, or `direct`), and `referrer_medium`/`referrer_campaign` if the page URL has `?utm_source=...&utm_medium=...&utm_campaign=...`. UTM params win over `document.referrer` when both are present; same-origin referrers are normalised to `direct`. Added 2026-06-29 — no backend changes needed, since the Worker already passes through arbitrary tag keys.
- Sent via `fetch(..., {keepalive: true})` so it survives page unload, to `https://atc-freq-metrics.mark-78f.workers.dev`

**Grafana:** `/Users/mark/Projects/atc_freq/grafana/website.json` — 9 panels: Page Views, Unique Visitors, CTA Clicks, and Reached Bottom of Page (100% scroll) as stat tiles, plus Page Views Over Time, CTA Clicks by Button, Scroll Depth Funnel, Visitors by Country, and Traffic Sources (referrer/UTM breakdown) as charts. All query `atc_metrics` filtered to `measurement = 'web_event'`.

Import via Grafana → Dashboards → New → Import → Upload JSON, mapping the `DS_NEONDB` prompt to the existing NeonDB Postgres data source. Panels are hardcoded to datasource UID `cfofy105jfxtsf`, the same UID used by the existing app dashboards in this Grafana instance — if importing elsewhere, Grafana's import screen lets you re-map it.

**Status: imported and confirmed working** — page views, CTA clicks, and scroll depth are populating live as of 2026-06-29.

**Privacy policy:** Section 6 of `docs/privacy-policy.html` discloses this in plain, non-itemized language (deliberately condensed — an earlier draft itemized every tracked event and button name, which read as alarming for what's a small amount of anonymous, aggregate data).

## 10. SEO

- `<title>` / `<meta name="description">` — keyword-led, under typical SERP truncation length
- `<link rel="canonical" href="https://atc-frequencies.app/">`
- `<meta name="robots" content="index, follow, max-image-preview:large">`
- Open Graph + Twitter Card tags, using `feature-graphic-1024x500.jpg` as the social preview image
- Two JSON-LD blocks: `MobileApplication` (name, price, screenshots, downloadUrl) and `WebSite`/`Organization` (links to Play Store + GitHub)
- `docs/robots.txt` + `docs/sitemap.xml` (root + privacy policy)
- `www` → apex 301 redirect (Section 6) so Google doesn't see duplicate content under two hostnames
- `theme-color` (`#0B1120`) + `apple-touch-icon`

**Cloudflare auto-injects its own `robots.txt` content** above whatever's served from origin — a default "Content-Signal" block disallowing AI *training* crawlers (GPTBot, ClaudeBot, Google-Extended, etc.). This does **not** affect search indexing — Googlebot/Bingbot (the actual search crawlers) aren't in that list, only AI-training-specific user agents are. No action needed.

**Manual step not done by Claude (needs a Google/Microsoft account):** submit the sitemap in Google Search Console and Bing Webmaster Tools, to get the site crawled promptly rather than discovered organically.

## 11. Pricing

The app is **not free** — £1.19 on Google Play (UK), which is the VAT-inclusive price for a £0.99 (ex-VAT) base. The website states the actual displayed price (`£1.19`) plus a note that Google Play shows it in the visitor's local currency — this avoids the site trying to do its own (inevitably approximate) currency conversion, since Google Play already localizes pricing correctly per region. Also fixed the same number in the `MobileApplication` JSON-LD `offers.price` — it had been incorrectly hardcoded to `"0"` before this was caught.

If the Play Store price ever changes, update both:
- The CTA paragraph text in `docs/index.html` (search for "one-time purchase")
- The JSON-LD `"offers": { "price": ... }` block in the same file

## 12. Known Gotchas

- **`docs/` is the GitHub Pages source** for `mowen7711.github.io/ATC-Frequencies/` — anything placed there is publicly fetchable by URL, regardless of whether `index.html` links to it. Internal documents (`marketing-strategy.md`, `marketing/outreach-log.md`, `marketing/reddit-rtlsdr-draft.md`, this repo's own Docmost export) were originally inside `docs/` and have been moved to `internal/` at the repo root for exactly this reason. Anything genuinely public-facing belongs in `docs/`; anything internal belongs in `internal/` or outside `docs/` entirely.
- `docs/` also still contains unused files not deployed to the server: `dashboard-preview.html`, `splash-preview.html`, unused feature-graphic size variants, and uncropped screenshot originals (`ss1.jpeg` etc., as opposed to the `-cropped` versions actually used). These are harmless (not sensitive) but also not needed in `docs/` — low priority cleanup if ever revisited.
- The pre-existing broad `443/tcp ALLOW Anywhere` ufw rule (Section 7) — watch for this resurfacing if `ufw` is ever reset or reconfigured.
- Cloudflare IP ranges (Section 7) need periodic re-sync into `ufw`.

## 13. Runbook — Common Tasks

**Edit and redeploy the site:**
1. Edit `docs/index.html` (or other deployed file) locally
2. Run the explicit-file-list `rsync` command from Section 8
3. `curl -I https://atc-frequencies.app/` to confirm `200`

**Redeploy the metrics worker after editing `metrics-relay/index.js`:**
```bash
cd metrics-relay
npx wrangler deploy
```
Verify with `npx wrangler tail --format pretty` while triggering a test request — look for `Ok`, not `NeonDB insert error`.

**SSH into the server:**
```bash
ssh root@100.103.65.20   # Tailscale must be connected on your Mac first
```

**Check nginx config validity before reloading:**
```bash
ssh root@100.103.65.20 "nginx -t && systemctl reload nginx"
```

**View current firewall rules:**
```bash
ssh root@100.103.65.20 "ufw status numbered"
```
