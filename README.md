# Cockpit

A browser-based launcher and remote desktop client built for Tesla's center display.

![Cockpit on Tesla](docs/img/hero.png)

> Not affiliated with, endorsed by, or related to Tesla, Apple, or any streaming service.

---

## Why

Tesla's browser is capable, but it has no shortcuts, no keyboard, and no way to push a URL from your phone to the screen. Cockpit fills that gap. It runs entirely in the browser — no app install, no vehicle API access, no credentials collected.

The Mac remote desktop feature goes further: it lets you reach your full macOS desktop from the car seat, using only a Cloudflare Tunnel and noVNC. Nothing is proxied through a third-party server.

---

## Features

- **Streaming launcher** — one-tap access to major streaming services, with an optional theater-mode URL boost
- **Mac remote desktop** — reach your Mac's screen from the Tesla browser via Cloudflare Tunnel and noVNC (self-hosted, end-to-end)
- **On-screen keyboard** — full keyboard overlay inside the remote desktop view, designed for touchscreen use
- **Voice dictation** — microphone button for hands-free text input in the remote session
- **Phone-to-screen URL pairing** — scan a QR code with your phone, send any URL to the car screen instantly
- **Maps shortcut** — push a destination from your phone's GPS directly to the launcher

---

## How it works

Cockpit is a static web application hosted on Vercel. The launcher layer requires no backend: HTML, CSS, and a small amount of JavaScript.

Phone-to-screen pairing uses Firebase Realtime Database as an ephemeral relay. Your phone writes a URL to a session key; the Tesla browser reads it and navigates. The payload is the URL only — no account, no credentials, no persistent storage.

The Mac remote desktop path is entirely self-hosted. A Cloudflare Tunnel on your Mac exposes a local websockify process (which bridges WebSocket to VNC) through your own Cloudflare-managed domain. Cockpit's custom noVNC build adds the on-screen keyboard and voice dictation overlay on top. Cloudflare Access optionally gates the tunnel behind Google OAuth so only your email can reach it.

---

## Setup

### Use the launcher (no install)

Go to [cockpit.thegridbase.com](https://cockpit.thegridbase.com) from any browser, including Tesla's.

No account required. Phone pairing works by scanning the QR on screen.

### Add Mac remote desktop (your own Mac)

You need: a Cloudflare account with a domain you control, a Mac running macOS Sonoma or later, and Homebrew.

```bash
git clone https://github.com/thegridbase/cockpit.git
cd cockpit
bash scripts/setup-mac.sh
```

The script installs cloudflared, websockify, and noVNC; creates a Cloudflare Tunnel; and registers both services as launchd agents so they start on boot. After the script finishes, follow the three manual steps it prints: enable macOS Screen Sharing, configure Cloudflare Access, and test.

Full guide: [docs/MAC_REMOTE_SETUP.md](docs/MAC_REMOTE_SETUP.md)

### Self-host the launcher (your own domain)

Fork this repo. Deploy to Vercel (or any static host). Set the Firebase environment variables in your project settings. Point your domain at the deployment.

The Firebase database rules are in `database.rules.json`. Sessions are keyed by a short random ID and contain only a URL string.

---

## Requirements

| Component | Requirement |
|---|---|
| Tesla | Any model with the built-in browser (no version restriction known) |
| Mac remote desktop | macOS Sonoma 14+ (Apple Silicon or Intel) |
| Mac remote desktop | Homebrew installed |
| Mac remote desktop | Cloudflare account (free tier) with a domain you control |
| Phone pairing | Any smartphone browser — no app install |

---

## Privacy

- No user accounts, no email collection, no passwords
- Phone pairing payload is the URL only; sessions expire on navigation
- Mac tunnel traffic goes directly from your Mac to your Cloudflare domain — nothing routes through Cockpit servers
- No analytics, no tracking scripts

---

## Disclaimer

Cockpit is an independent project. It is not affiliated with, endorsed by, or in any way connected to Tesla, Inc., Apple Inc., or any streaming service. It does not interact with vehicle systems, vehicle APIs, or any third-party account credentials.

Use of Mac remote desktop and Cloudflare Tunnel is subject to your own Cloudflare account terms. Streaming service access is subject to each service's terms of use.

---

## License

All rights reserved. See [LICENSE](LICENSE).

---

## Contributing

Not open for external contributions at this time.
