# Cloudflare Access for `mac.thegridbase.com`

This puts a Google OAuth wall in front of your Mac's remote desktop.
Without this, anyone who finds the URL can reach the VNC password prompt.
With this, only logged-in `cankilic.mail@gmail.com` can reach the page.

**Free.** No credit card. Takes 5 minutes.

---

## 1. Activate Zero Trust (one-time)

1. Go to https://one.dash.cloudflare.com
2. Sign in with the same Cloudflare account that owns `thegridbase.com`
3. If this is your first Zero Trust visit:
   - Pick a team name (e.g. `cankilic`) — this becomes `cankilic.cloudflareaccess.com`
   - Choose the **Free plan** (no card required, 50 users included)

---

## 2. Add Google as a login method

1. **Settings** → **Authentication** → **Login methods** → **Add new**
2. Pick **Google**
3. Leave Client ID / Secret blank — Cloudflare provides a default Google OAuth app for free plans
4. Save & test (a popup confirms it works)

---

## 3. Create the Access Application

1. **Access** → **Applications** → **Add an application**
2. Pick **Self-hosted**
3. Fill in:
   - **Application name:** Cockpit Mac
   - **Session duration:** `24 hours` (re-login once a day)
   - **Application domain:**
     - Subdomain: `mac`
     - Domain: `thegridbase.com`
     - Path: leave blank
4. Under **Identity providers**, check **Google**
5. Click **Next**

---

## 4. Add the policy

1. **Policy name:** `Only me`
2. **Action:** `Allow`
3. **Session duration:** Same as application
4. Under **Configure rules** → **Include**:
   - Selector: **Emails**
   - Value: `cankilic.mail@gmail.com`
5. Click **Next** → **Add application**

---

## Done. Test it.

1. Open https://mac.thegridbase.com in a private window
2. You should see Cloudflare's Google login screen
3. Sign in with `cankilic.mail@gmail.com`
4. After approval, the noVNC page loads

If anyone else tries with a different email, they get rejected at the OAuth step — they never reach the VNC password prompt.

---

## Adding another email later (e.g. for the wife)

Access → Applications → Cockpit Mac → Policies → `Only me` → edit Include list → add email → Save.

## Revoking access (if a device is lost)

Access → Users → find the user → **Revoke all sessions**. They'll be forced to log in again on next visit — and you can also remove them from the policy.
