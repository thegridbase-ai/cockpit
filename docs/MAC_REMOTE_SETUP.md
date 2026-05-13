# Mac Remote Desktop Setup

This guide walks through setting up your Mac so you can reach its screen from the Tesla browser (or any browser) using Cockpit's remote desktop feature.

The tunnel runs between your Mac and your own Cloudflare-managed domain. Nothing routes through Cockpit servers.

---

## Prerequisites

Before you start, confirm you have:

- **macOS Sonoma 14 or later** (Apple Silicon or Intel — both supported)
- **Homebrew** installed (`/bin/bash -c "$(curl -fsSL https://brew.sh/install.sh)"`)
- **A Cloudflare account** (free tier is enough) with a domain you control
- **A subdomain decided** — for example, `desktop.yourdomain.com`. You will point this at the tunnel during setup.

The setup script creates the tunnel and writes the DNS record automatically, but you need the domain to exist in your Cloudflare account first.

---

## Step 1: Clone the repo and run the setup script

```bash
git clone https://github.com/thegridbase/cockpit.git
cd cockpit
bash scripts/setup-mac.sh
```

The script does the following, in order:

1. Installs `cloudflared` and `websockify` via Homebrew and pipx
2. Downloads noVNC and installs the custom Cockpit keyboard overlay
3. Opens a browser window for Cloudflare login (one-time auth, saves a certificate locally)
4. Creates a Cloudflare Tunnel named `cockpit-mac`
5. Writes the tunnel config to `~/.cloudflared/config.yml` and copies it to `/etc/cloudflared/`
6. Routes the DNS CNAME for your subdomain to the tunnel automatically
7. Installs `cloudflared` as a system launchd daemon (survives reboots, runs as root)
8. Installs `websockify` as a user launchd agent on port 6080

The script is idempotent — safe to re-run if something fails partway through.

When it finishes, it prints three manual steps. Complete them before testing.

---

## Step 2: Enable macOS Screen Sharing

The tunnel bridges to the macOS built-in VNC server. You must turn it on manually.

1. Open **System Settings**
2. Go to **General** > **Sharing**
3. Turn **Screen Sharing** on
4. Click the info button (i) next to Screen Sharing
5. Under "Allow access for", select **Only these users** and add your Mac user account
6. Scroll down to **VNC viewers may control screen with password**
7. Click **Set Password** and choose a strong password (16 or more characters recommended)
8. To keep the Mac reachable when the display sleeps, go to **System Settings** > **Lock Screen** and set "Turn display off on battery when inactive" to **Never** (or use `caffeinate -d` when needed)

The VNC password is what you enter in the noVNC connect screen. It is not your macOS login password.

---

## Step 3: Set up Cloudflare Access (recommended)

Without this step, anyone who finds your tunnel URL can reach the VNC password prompt. Cloudflare Access puts a Google OAuth gate in front of it. Only the email addresses you allow can get past the login screen.

Follow the instructions in [CLOUDFLARE_ACCESS.md](CLOUDFLARE_ACCESS.md) to:

- Activate Cloudflare Zero Trust (free, no credit card)
- Add Google as a login method
- Create a Self-hosted Access Application for your subdomain
- Add a policy that allows only your email

This takes about five minutes and costs nothing on the free plan.

If you choose to skip this step, make sure your VNC password is strong. The password is the only thing between the open internet and your screen.

---

## Step 4: Test from a desktop browser

Before testing from the car, verify the full flow from a laptop or desktop browser.

1. Open your tunnel URL (e.g., `https://desktop.yourdomain.com`) in a private/incognito window
2. If you set up Cloudflare Access, you will see a Google login screen — sign in with the allowed email
3. After passing Access, the noVNC connect screen loads
4. Click **Connect**
5. Enter your VNC password
6. Your Mac's screen should appear in the browser

If the screen appears but is the wrong size, add `?resize=scale` to the URL.

---

## Step 5: Test from Tesla

1. Open Cockpit at `cockpit.thegridbase.com` (or your self-hosted URL) on the Tesla browser
2. Tap the **Mac** card in the launcher
3. The same Cloudflare Access login and noVNC flow runs inside the Tesla browser
4. After connecting, use Cockpit's on-screen keyboard for text input — the standard Tesla browser keyboard does not inject keypresses into the VNC session

You can bookmark the direct tunnel URL in the Tesla browser if you prefer to skip the Cockpit launcher.

---

## Troubleshooting

**"Tunnel has no active connection"**

The cloudflared service is not running. Restart it:

```bash
sudo launchctl stop com.cloudflare.cloudflared
sudo launchctl start com.cloudflare.cloudflared
```

Check logs:
```bash
sudo log show --predicate 'process == "cloudflared"' --last 5m
```

**"ARD authentication failed" or "Incorrect password"**

The VNC password is the one you set in Screen Sharing settings, not your macOS user login password. Go back to System Settings > Sharing > Screen Sharing > (i) and reset it.

**"Black screen, but the keyboard responds"**

The display resolution is mismatching the browser viewport. Add `?resize=scale` to your tunnel URL:

```
https://desktop.yourdomain.com/?resize=scale
```

**"Voice dictation button shows no audio"**

The browser needs microphone permission. In Safari or Chrome, go to the site's settings and allow microphone access. On Tesla's browser, tap the address bar lock icon and check permissions.

**websockify not running after reboot**

The user launchd agent may not have loaded. Re-load it:

```bash
launchctl load -w ~/Library/LaunchAgents/com.cockpit.websockify.plist
```

---

## Uninstall

```bash
sudo cloudflared service uninstall
launchctl unload ~/Library/LaunchAgents/com.cockpit.websockify.plist
rm -rf ~/.cockpit-mac ~/Library/LaunchAgents/com.cockpit.websockify.plist ~/.cloudflared
```

This removes the services and local files. The Cloudflare Tunnel record and DNS CNAME remain in your Cloudflare dashboard — delete them there if you no longer need them.
