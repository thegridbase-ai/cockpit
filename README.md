# Cockpit

A browser-based launcher and remote desktop client built for in-car center displays — including the Tesla browser.

![Cockpit on Tesla](docs/img/hero.png)

> Not affiliated with, endorsed by, or related to Tesla, Apple, or any streaming service.

---

## The headline feature

**Voice-dictate into your Mac terminal from your car seat.**

Cockpit ships a self-hosted Mac remote desktop with a custom overlay built on noVNC. The overlay adds two things the Tesla browser does not have on its own:

1. **An on-screen keyboard** that sends real keystrokes to your Mac (Tesla's native keyboard cannot type into VNC).
2. **A microphone button** that uses the Web Speech API to transcribe your voice and inject it as keystrokes — directly into Terminal, Notes, a chat window, anywhere your Mac has focus.

The whole path runs over Cloudflare Tunnel: nothing is proxied through a third-party server, your Mac talks only to your own Cloudflare-managed subdomain, and an optional Cloudflare Access layer gates everything behind Google OAuth.

---

## Why

The Tesla browser is surprisingly capable — but it has no shortcuts, no real keyboard, no way to push a URL from your phone, and no way to reach your computer. Cockpit fills those gaps. Everything runs in the browser. No app install, no vehicle API access, no credentials collected.

---

## Features

- **Mac remote desktop** — reach your Mac's screen from any in-car browser via Cloudflare Tunnel + noVNC. Self-hosted end-to-end.
- **On-screen keyboard overlay** — full QWERTY built for touchscreens, sends actual keystrokes into VNC. Designed to bypass the limitation that Tesla's native keyboard can't type into the remote desktop session.
- **Voice dictation to Mac** — tap the microphone, speak, and the transcript types itself into whatever app has focus on your Mac. Tested into Terminal, Notes, Slack, and code editors.
- **Streaming launcher** — one-tap access to Netflix, YouTube, Disney+, Max, and Apple TV+, with an optional Auto-Fullscreen toggle that routes through a YouTube redirect to trigger immersive playback on supported in-car browsers.
- **Phone-to-screen URL pairing** — scan a QR code on the car screen with your phone, push any HTTPS URL back, and Cockpit navigates to it instantly. No app required.
- **Maps shortcut with phone GPS** — the phone-pairing page can grab your phone's location and push a Maps URL centered on you to the screen, in one tap.
- **Cache-bust refresh** — a Refresh pill in the top bar forces a fresh HTML load, so updates land on the car screen without fighting the in-car browser cache.
- **Build version visible at all times** — every build prints its UTC timestamp and short commit hash to the top bar, so you always know which version you're looking at.

---

## How it works

Cockpit is a static web application hosted on Vercel. The launcher layer requires no backend: HTML, CSS, and a small amount of JavaScript.

Phone-to-screen pairing uses Firebase Realtime Database as an ephemeral relay. The phone writes a single URL to a short, random session key; the car browser reads it and navigates; the entry is deleted. The payload is the URL only — no account, no credentials, no persistent storage.

The Mac remote desktop path is fully self-hosted. A Cloudflare Tunnel on your Mac exposes a local websockify process (which bridges WebSocket to VNC) through your own Cloudflare-managed subdomain. Cockpit ships a custom `index.html` that replaces the default noVNC landing page; it embeds the standard noVNC viewer in an iframe and lays the on-screen keyboard plus the microphone button on top, talking to the noVNC `RFB` API directly to send keystrokes.

Cloudflare Access can optionally gate the tunnel behind Google OAuth, so only the email addresses you allow can even reach the VNC login.

---

## Setup

### Use the launcher (no install)

Open [cockpit.thegridbase.com](https://cockpit.thegridbase.com) in any browser, including the Tesla browser. Bookmark it for one-tap access.

The launcher works out of the box for streaming, phone pairing, and Maps. The Mac remote desktop card only works for the maintainer's domain by default — to connect to your own Mac you need the setup below.

### Add Mac remote desktop (your own Mac, your own domain)

You need a Cloudflare account with a domain you control, a Mac running macOS Sonoma or later, and Homebrew.

```bash
git clone https://github.com/cankilic-gh/cockpit.git
cd cockpit
DOMAIN=mac.your-domain.com bash scripts/setup-mac.sh
```

The script installs `cloudflared`, `websockify` (via `pipx`), and `noVNC`; creates a Cloudflare Tunnel; routes your chosen subdomain to it; and registers both processes as launchd services so they survive reboots. It also installs Cockpit's custom noVNC overlay (the keyboard + microphone UI) into the noVNC directory.

When the script finishes it prints three manual steps:
1. Turn on macOS Screen Sharing
2. Set up Cloudflare Access (recommended, free, blocks everyone except your Google email)
3. Test from any browser, then from the car

Full walkthrough: [docs/MAC_REMOTE_SETUP.md](docs/MAC_REMOTE_SETUP.md) · [docs/CLOUDFLARE_ACCESS.md](docs/CLOUDFLARE_ACCESS.md)

### Self-host the launcher (your own domain)

Fork this repo. Set the Firebase environment variables in your hosting platform. Edit `index.html` to point the **Mac** card at your own remote-desktop subdomain. Deploy to Vercel or any static host.

The Firebase database rules are in `database.rules.json`. Sessions are keyed by a short random ID and contain only an HTTPS URL string.

---

## Requirements

| Component | Requirement |
|---|---|
| In-car browser | Any Chromium-based browser; tested on Tesla Model 3 / Y / S / X |
| Mac remote desktop (host) | macOS Sonoma 14+ (Apple Silicon or Intel) |
| Mac remote desktop (host) | Homebrew installed |
| Mac remote desktop (host) | Cloudflare account (free tier) with a domain you control |
| Voice dictation | Microphone permission in the in-car browser; Web Speech API support (Chromium-based) |
| Phone pairing | Any smartphone browser — no app install |

---

## Architecture

```
Tesla browser ─┬─► cockpit.thegridbase.com (Vercel · static HTML)
               │       │
               │       └─► mac.<your-domain> ─► Cloudflare Tunnel ─► localhost:6080 (websockify) ─► localhost:5900 (Screen Sharing)
               │
               └─► Firebase RTDB (60-second URL relay) ◄─── phone (QR pair)
```

---

## Privacy

- No user accounts, no email collection, no passwords
- Phone pairing payload is the URL only; sessions expire on navigation
- Mac tunnel traffic goes directly from your Mac to your own Cloudflare subdomain — nothing routes through Cockpit-controlled servers
- No analytics, no tracking scripts

Full policy: [cockpit.thegridbase.com/privacy](https://cockpit.thegridbase.com/privacy)

---

## Disclaimer

Cockpit is an independent project. It is not affiliated with, endorsed by, or in any way connected to Tesla, Inc., Apple Inc., Netflix, Inc., The Walt Disney Company, Warner Bros. Discovery, Alphabet Inc., or any streaming service. It does not interact with vehicle systems, vehicle APIs, or any third-party account credentials. All trademarks belong to their respective owners and are referenced under nominative fair use.

Driving safely is your responsibility. Use streaming and remote desktop features only when parked.

---

## License

All rights reserved. See [LICENSE](LICENSE).

---

## Contributing

Not open for external contributions at this time.

---

A project by [Can Kilic](https://thegridbase.com). Part of [TheGridBase](https://thegridbase.com) — a personal portfolio of small, independent web projects.
