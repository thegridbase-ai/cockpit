# Cockpit

In-cabin launcher for EVs. Open the page on the car's center display, scan a QR with your phone, push URLs from your phone to the screen.

- **Live**: https://cockpit.thegridbase.com
- **Pair page**: opens automatically when you scan the QR; no install
- **Architecture**: phone → Firebase Realtime DB (URL relay only) → car
- **Privacy**: no credentials collected, no email/password fields, payload is the URL only

## What this is not

- Not affiliated with, endorsed by, or related to any vehicle manufacturer.
- Does not interact with vehicle systems, vehicle accounts, or third-party streaming logins.
- Does not collect, store, or transmit credentials of any kind.

## Stack

Static HTML, Firebase Realtime Database, deployed on Vercel.
