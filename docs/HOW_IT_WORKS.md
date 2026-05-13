# How Cockpit Works

Technical overview for developers and technically curious users.

---

## Architecture

```
                        COCKPIT LAUNCHER
                  (static HTML/JS on Vercel)
                           |
          +----------------+----------------+
          |                                 |
    PHONE PAIRING                   MAC REMOTE DESKTOP
          |                                 |
   Firebase RTDB                    Cloudflare Tunnel
  (ephemeral relay)                         |
          |                         websockify :6080
   phone writes URL                          |
   Tesla browser reads               macOS VNC :5900
   and navigates                   (Screen Sharing)
          |                                 |
     [session key]                  noVNC custom build
    expires on nav                  in Tesla browser
```

The two main features are architecturally independent. The launcher and phone pairing require no infrastructure beyond Vercel and a Firebase project. The Mac remote desktop requires cloudflared and websockify running on the Mac — nothing flows through Cockpit's servers.

---

## Launcher

The launcher is a single `index.html` file with no build step and no framework. It is deployed to Vercel as a static asset.

Each streaming service tile encodes a direct URL. Tapping a tile either navigates the Tesla browser directly or, when the Streaming Boost toggle is on, redirects through a modified URL that requests the desktop/TV-optimized version of the page. This is a plain HTTP redirect — no content is intercepted or modified.

The Streaming Boost toggle is opt-in and off by default. Its state is stored in `localStorage` only. No preference is sent to any server.

---

## Phone Pairing

The pairing flow uses Firebase Realtime Database as an ephemeral message bus.

1. The Tesla browser generates a short random session ID on load
2. It renders a QR code encoding `pair.html?session=<id>`
3. The user scans the QR with their phone
4. `pair.html` loads on the phone, writes the destination URL to `sessions/<id>/url` in the RTDB
5. The Tesla browser is listening on that path with an `onValue` listener
6. On receiving the write, the Tesla browser navigates to the URL
7. The session record is not explicitly deleted — Firebase's TTL rules expire it

The RTDB security rules (`database.rules.json`) allow unauthenticated reads and writes scoped to `sessions/<id>`. The payload is a string (the URL). No user identity, no IP address, no metadata is stored.

---

## noVNC Custom Overlay

Cockpit replaces the default noVNC `index.html` with a custom build (`novnc-custom/index.html`). The standard noVNC interface is not designed for touchscreens and has no keyboard fallback for environments where the system keyboard cannot inject keypresses into the VNC canvas.

The custom overlay adds:

- **On-screen keyboard** — a full QWERTY layout rendered in HTML/CSS. Keys fire `sendKey` calls into the noVNC RFB instance using the correct X11 keysym codes, which the macOS VNC server understands
- **Shift and modifier state** — the keyboard tracks shift/caps state visually and passes the correct modifier flags with each keypress
- **Voice dictation button** — calls the Web Speech API (`SpeechRecognition`) and types the recognized text through the same `sendKey` path, one character at a time
- **Fullscreen and resize controls** — overlay buttons to enter fullscreen and reload with `?resize=scale` without leaving the noVNC session

The overlay communicates with the underlying noVNC RFB object through the exported `rfb` variable that the noVNC core sets on the window after connection.

---

## Cloudflare Tunnel + Mac VNC

The remote desktop path avoids port-forwarding and dynamic DNS by using a Cloudflare Tunnel (formerly Argo Tunnel).

On the Mac, `cloudflared` runs as a system service. It opens an outbound connection to Cloudflare's edge and registers the tunnel. Cloudflare routes inbound HTTPS traffic for the configured subdomain to `localhost:6080`.

`websockify` listens on port 6080. It speaks WebSocket on the browser side and raw TCP on the VNC side, proxying to the macOS Screen Sharing service on `localhost:5900`.

noVNC in the browser speaks the RFB protocol over WebSocket, which websockify translates to the VNC wire protocol that macOS Screen Sharing expects.

Cloudflare Access (optional but recommended) intercepts requests at Cloudflare's edge before they reach the tunnel. It validates a signed JWT from the OAuth provider and only forwards the request if the identity matches the policy. The Mac never sees an unauthenticated request.

---

## What does not exist

- No Cockpit account system
- No server-side code (the pairing relay is Firebase, not a custom server)
- No video or audio capture of the Tesla session
- No interaction with Tesla's vehicle API or any OEM API
- No analytics or telemetry in any Cockpit-controlled component
