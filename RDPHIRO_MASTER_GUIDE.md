# rdphiro — Master Operational & Deployment Guide

> **Project Name**: `rdphiro` (powered by MeshCentral)  
> **Purpose**: Self-hosted Remote Desktop (RDP / KVM), Remote Shell, and Endpoint Management Platform.  
> **Hosting Target**: AWS Lightsail (Ubuntu 24.04 / 22.04 LTS).

---

## Table of Contents
1. [Architecture & How It Works](#1-architecture--how-it-works)
2. [Project Customization: What Needs to be Changed?](#2-project-customization-what-needs-to-be-changed)
3. [Local Testing & Verification](#3-local-testing--verification)
4. [Master "How to Use rdphiro" Operations Guide](#4-master-how-to-use-rdphiro-operations-guide)
   - [Initial Admin Account Creation](#a-initial-admin-account-creation)
   - [Device Groups](#b-device-groups)
   - [Installing Agents (Windows, Linux, macOS)](#c-installing-agents)
   - [Remote Desktop Control (KVM)](#d-remote-desktop-control-kvm)
   - [Remote Terminal (Shell)](#e-remote-terminal-shell)
   - [Remote File Management](#f-remote-file-management)
   - [Native Microsoft RDP Routing (mstsc)](#g-native-microsoft-rdp-routing-mstsc)
   - [Power Management & Hardware Telemetry](#h-power-management--hardware-telemetry)
5. [Complete AWS Lightsail Deployment Guide](#5-complete-aws-lightsail-deployment-guide)
   - [Step 1: Create Lightsail Instance](#step-1-create-lightsail-instance)
   - [Step 2: Allocate & Attach Static IP](#step-2-allocate--attach-static-ip)
   - [Step 3: Configure Lightsail Firewall](#step-3-configure-lightsail-firewall)
   - [Step 4: Configure Domain DNS](#step-4-configure-domain-dns)
   - [Step 5: Clone & Provision with Automated Script](#step-5-clone--provision-with-automated-script)
   - [Step 6: Configure Domain & Let's Encrypt SSL](#step-6-configure-domain--lets-encrypt-ssl)
   - [Step 7: Service Verification & Auto-Start](#step-7-service-verification--auto-start)
6. [Security Hardening & Best Practices](#6-security-hardening--best-practices)
7. [Backups & Disaster Recovery](#7-backups--disaster-recovery)
8. [Optional: Using Nginx as a Reverse Proxy](#8-optional-using-nginx-as-a-reverse-proxy)

---

## 1. Architecture & How It Works

```
                        +---------------------------+
                        |  Your Web Browser         |
                        |  (Admin / Operator)       |
                        +-------------+-------------+
                                      |
                     HTTPS / WSS:443  |
                                      v
                        +---------------------------+
                        |  AWS Lightsail Instance   |
                        |  rdphiro Server           |
                        |  (Static IP: 80 / 443)    |
                        +-------------+-------------+
                                      ^
                                      | Outbound WSS:443
               +----------------------+----------------------+
               |                      |                      |
      +--------+--------+    +--------+--------+    +--------+--------+
      | Target Windows  |    | Target Linux    |    | Target macOS    |
      | (rdphiroagent)  |    | (rdphiroagent)  |    | (rdphiroagent)  |
      +-----------------+    +-----------------+    +-----------------+
      [ Behind Home NAT ]    [ Behind Corp NAT ]    [ Behind 4G/5G ]
```

### Why rdphiro Can Reach Any Computer Without Port-Forwarding:
Unlike traditional RDP (which requires opening port 3389 and setting up router port forwarding), **`rdphiro` works via reverse WebSocket tunnels**:
- When you install `rdphiroagent` on any PC, it makes an **outbound** HTTPS/TLS connection on port 443 to your Lightsail server.
- Firewalls, routers, and NAT allow outbound port 443 traffic by default.
- Once connected, a persistent two-way tunnel is maintained. You can now control the computer, view its screen, open a shell, or transfer files from anywhere in the world.

---

## 2. Project Customization: What Needs to be Changed?

### ⚠️ Never Edit Core `.js` Engine Files
Do not edit core files such as `meshcentral.js`, `webserver.js`, or `agenttypes.js`. Modifying these files will cause Git merge conflicts whenever you update the codebase (`git pull`).

Instead, `rdphiro` is completely customized through **configuration and override files**:

| File / Folder | Role in rdphiro |
|---|---|
| `meshcentral-data/config.json` | Controls server title (`rdphiro`), agent display name (`rdphiro Agent`), service name (`rdphiroagent`), ports, domain, and Let's Encrypt. |
| `config.lightsail.json.template` | Pre-configured production template ready to be deployed on your AWS Lightsail server. |
| `systemd/rdphiro.service` | Linux service unit to keep `rdphiro` running 24/7 in the background with auto-restart on boot or crash. |
| `scripts/run-local.sh` | One-click local test launcher. |
| `scripts/setup-lightsail.sh` | One-shot setup script for Ubuntu on AWS Lightsail. |
| `.gitignore` | Updated to ensure certificates, database records, and encryption keys are never committed to Git. |

---

## 3. Local Testing & Verification

### Step 1: Install Node.js >= 22
`rdphiro` (MeshCentral 1.3.1) requires **Node.js >= 22.12.0**.

On your local CachyOS / Arch machine:
```bash
sudo pacman -S nodejs npm
```
*Or without root via NVM:*
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc # or source ~/.zshrc
nvm install 22
nvm use 22
```

Verify version:
```bash
node -v   # Must be >= v22.12.0
npm -v
```

### Step 2: Run rdphiro Locally
Run the prepared local test script:
```bash
./scripts/run-local.sh
```
This script will:
- Check Node.js version.
- Run `npm install --production` if dependencies are missing.
- Launch `rdphiro` using `meshcentral-data/config.json` on local ports:
  - **HTTPS**: `https://localhost:4430`
  - **HTTP (Redirect)**: `http://localhost:8080`

### Step 3: Access the Web UI
1. Open your browser and navigate to `https://localhost:4430`.
2. Because the server uses a self-signed development certificate locally, your browser will show a security warning. Click **Advanced -> Proceed to localhost (unsafe)**.
3. You will see the **rdphiro** login screen!
4. Click **Create One** to register your initial administrator account.

---

## 4. Master "How to Use rdphiro" Operations Guide

### A. Initial Admin Account Creation
- The first user account created on a fresh installation automatically receives **Full Server Administrator Privileges**.
- Remember the username and password, as this account has root control over all device groups, settings, and users.

### B. Device Groups
Device groups allow you to organize your endpoints and configure access permissions:
1. Click the **My Devices** tab on top.
2. Click **Add Device Group**.
3. Choose:
   - **Manage using an agent** (Standard): Choose this for installing the background agent on your endpoints.
   - **Manage without agent**: For direct connection to local IP addresses (RDP, VNC, SSH).
4. Give your group a name (e.g. `Personal Laptops`, `Production Servers`, `Family`).

### C. Installing Agents

In your device group, click **Add Agent**:

#### Windows:
1. Select **Windows**.
2. Click **Download** to get `rdphiroagent.exe`.
3. On the target Windows machine, right-click `rdphiroagent.exe` and select **Run as Administrator**.
4. Click **Install**.
   - This registers `rdphiroagent` as a Windows Service.
   - It will start automatically when Windows boots, even before anyone logs in.
   - If you only want temporary one-time support without installing a permanent service, choose **Connect** instead of Install.

#### Linux (Ubuntu, Debian, Arch, CentOS, Fedora, Raspberry Pi):
1. Select **Linux**.
2. Copy the one-line install command generated by the server:
   ```bash
   curl -s "https://rdphiro.yourdomain.com/meshagents?script=1" | sudo bash
   ```
3. Run it in the Linux terminal. It automatically downloads the binary and creates `systemd/system/rdphiroagent.service`.

#### macOS:
1. Select **Apple OS X**.
2. Download the `.pkg` installer or copy the terminal command.
3. *Note*: In macOS System Settings -> Privacy & Security, grant **Accessibility** and **Screen Recording** permissions to the agent so it can capture the screen and control the mouse.

Within 5 seconds, the computer will appear in your device list with a green dot indicating it is online.

---

### D. Remote Desktop Control (KVM)
Click on any connected computer in your device list, then click the **Desktop** tab:
1. Click **Connect**.
2. You now see the remote computer's display in real time.
3. **Controls Toolbar**:
   - **Displays**: Switch between Monitor 1, Monitor 2, or view All Monitors simultaneously.
   - **Display Quality & Framerate**: Move the compression slider. Lower quality uses minimal bandwidth (great for mobile hotspots); high quality gives near 60 FPS crisp display.
   - **Full Screen**: Toggle full screen for a native desktop experience.
   - **Send Special Keys**: Send `Ctrl+Alt+Del`, `Win+L`, `Alt+Tab`, or custom key combinations.
   - **Clipboard**: Text copied on your local machine can be pasted directly into the remote desktop, and vice versa.
   - **Block Remote Input**: Prevent the remote user's physical mouse and keyboard from interfering while you work.

---

### E. Remote Terminal (Shell)
Click on the **Terminal** tab:
1. Click **Connect**.
2. You get an instant terminal session directly into the OS:
   - **Windows**: Full PowerShell or CMD shell running as `NT AUTHORITY\SYSTEM`.
   - **Linux**: Full root bash shell.
3. The terminal runs completely in the background. The user sitting at the computer does not see any terminal windows open.

---

### F. Remote File Management
Click on the **Files** tab:
1. You will see the remote drive letters (`C:\`, `D:\` on Windows; `/` on Linux).
2. **Uploading**: Drag and drop any file from your local computer directly onto the browser window.
3. **Downloading**: Click any remote file and click **Download**.
4. **Folder Management**: Create folders, rename, or delete files.
5. **Direct Editing**: Click on text/config files (e.g. `.txt`, `.json`, `.yaml`, `.ini`) and click **Edit** to modify them directly in the browser editor.

---

### G. Native Microsoft RDP Routing (mstsc)
If you prefer Microsoft's native Remote Desktop client (`mstsc.exe`) over browser KVM:
1. In the device view, look under **Actions** -> **RDP**.
2. Download the lightweight **MeshCentral Router** tool (can be branded or run standalone).
3. It sets up a local loopback port (e.g. `127.0.0.1:33389`) that tunnels through your `rdphiro` server directly into the target machine's port 3389.
4. Launch `mstsc.exe` and connect to `127.0.0.1:33389`.
5. You get full native Windows RDP performance, multi-channel audio, and printer redirection without exposing port 3389 to the internet!

---

### H. Power Management & Hardware Telemetry
Click on the **Details** tab:
- **Telemetry**: View real-time CPU utilization, available RAM, network adapter MAC and IP addresses, OS build, and uptime.
- **Power Actions**:
  - **Restart**: Safely reboots the remote OS.
  - **Shutdown**: Powers off the machine.
  - **Wake-on-LAN**: If another computer on the same local subnet is running the agent, it can send a Wake-on-LAN magic packet to power on sleeping machines.

---

## 5. Complete AWS Lightsail Deployment Guide

### Step 1: Create Lightsail Instance
1. Log into your [AWS Lightsail Console](https://lightsail.aws.amazon.com/).
2. Click **Create instance**.
3. **Location**: Select the AWS region closest to your location (e.g., `us-east-1`, `eu-west-1`, `ap-south-1`).
4. **Platform**: `Linux/Unix`.
5. **Blueprint**: `OS Only` -> **Ubuntu 24.04 LTS** (or 22.04 LTS).
6. **Instance Plan**:
   - For 1–50 managed computers: Choose the **$3.50/mo** (512 MB RAM) or **$5.00/mo** (1 GB RAM - **Recommended**).
7. **Name**: `rdphiro-server`.
8. Click **Create instance** and wait 60 seconds for it to start.

---

### Step 2: Allocate & Attach Static IP
Dynamic public IPs change whenever an instance is stopped or restarted. A Static IP is permanent and free as long as it is attached to an instance:
1. In the Lightsail dashboard, click the **Networking** tab.
2. Click **Create static IP**.
3. Choose your instance (`rdphiro-server`) to attach it to.
4. Name it `rdphiro-static-ip` and click **Create**.
5. Copy the assigned IP address (e.g. `34.210.120.45`).

---

### Step 3: Configure Lightsail Firewall
In Lightsail:
1. Click on your `rdphiro-server` instance.
2. Click the **Networking** tab.
3. Under **IPv4 Firewall**, ensure these rules are present:
   - **SSH**: Port `22` (TCP)
   - **HTTP**: Port `80` (TCP) — *Crucial for Let's Encrypt automated certificate validation*.
   - **HTTPS**: Port `443` (TCP) — *Crucial for the Web UI and Agent WebSockets*.
4. (Optional) Under **IPv6**, you can disable IPv6 networking if you are only configuring IPv4 DNS.

---

### Step 4: Configure Domain DNS
Log into your DNS provider (Cloudflare, GoDaddy, Namecheap, Route 53):
1. Create an **A Record**:
   - **Type**: `A`
   - **Name / Host**: `rdphiro` (or `rdp`, or `@` if using root domain)
   - **IPv4 Address**: `<Your Lightsail Static IP>`
   - **TTL**: Auto or 300 seconds.
2. **If using Cloudflare**:
   - Set the Proxy Status to **DNS Only** (Grey Cloud) during initial setup.
   - *Reason*: Let's Encrypt requires direct HTTP challenge verification to port 80. Once the certificate is issued, Cloudflare proxying can be re-enabled if desired, but DNS-only provides maximum WebSocket speed.

---

### Step 5: Clone & Provision with Automated Script
Connect to your Lightsail instance using SSH (or click the terminal icon in the Lightsail console):

```bash
# 1. Update system packages and install git
sudo apt-get update && sudo apt-get install -y git

# 2. Clone your repository into /opt/rdphiro
sudo git clone https://github.com/YOUR_USERNAME/myrdp.git /opt/rdphiro
# (Or use scp/rsync to copy your local project folder to /opt/rdphiro)

# 3. Enter directory and run the automated setup script
cd /opt/rdphiro
sudo bash scripts/setup-lightsail.sh
```

The script automatically:
- Installs Node.js 22 LTS from NodeSource.
- Sets Linux capabilities (`cap_net_bind_service`) so Node can bind to ports 80 and 443 without needing root privileges.
- Creates a dedicated secure system user `rdphiro`.
- Installs all Node dependencies via `npm install --production`.
- Sets up `/etc/systemd/system/rdphiro.service`.

---

### Step 6: Configure Domain & Let's Encrypt SSL
Edit the active configuration file:
```bash
sudo nano /opt/rdphiro/meshcentral-data/config.json
```

Ensure the configuration matches your domain and email:
```json
{
  "$schema": "https://raw.githubusercontent.com/Ylianst/MeshCentral/master/meshcentral-config-schema.json",
  "settings": {
    "cert": "rdphiro.yourdomain.com",
    "port": 443,
    "redirPort": 80,
    "sessionKey": "GENERATE_A_RANDOM_LONG_SECRET_STRING_HERE",
    "allowHighQualityDesktop": true,
    "compression": true,
    "wsCompression": true,
    "agentWsCompression": true,
    "StrictTransportSecurity": true,
    "cleanNpmCacheOnUpdate": true
  },
  "domains": {
    "": {
      "title": "rdphiro",
      "title2": "Remote Access Platform",
      "newAccounts": true,
      "userNameIsEmail": true,
      "welcomeText": "rdphiro Remote Desktop Server",
      "agentCustomization": {
        "displayName": "rdphiro Agent",
        "description": "rdphiro secure remote desktop agent.",
        "companyName": "rdphiro",
        "serviceName": "rdphiroagent",
        "fileName": "rdphiroagent"
      },
      "consentMessages": { "title": "rdphiro" },
      "notificationMessages": { "title": "rdphiro" }
    }
  },
  "letsencrypt": {
    "email": "your-email@yourdomain.com",
    "names": "rdphiro.yourdomain.com",
    "production": true
  }
}
```

Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

---

### Step 7: Service Verification & Auto-Start
Start the service and check the logs:
```bash
# Start rdphiro
sudo systemctl start rdphiro

# View real-time logs
sudo journalctl -u rdphiro -f
```

You will see:
```text
rdphiro HTTP redirection server running on port 80.
rdphiro HTTPS server running on port 443.
Requesting Let's Encrypt certificate for rdphiro.yourdomain.com...
Certificate received and installed!
```

Open your browser and visit:
```
https://rdphiro.yourdomain.com
```
You will be greeted with a green padlock (trusted Let's Encrypt SSL) and your branded **rdphiro** login screen!

---

## 6. Security Hardening & Best Practices

### 1. Disable New Account Creation
As soon as you create your primary administrator account:
```bash
sudo nano /opt/rdphiro/meshcentral-data/config.json
```
Change:
```json
"newAccounts": false
```
Restart the server:
```bash
sudo systemctl restart rdphiro
```
Now, no uninvited users can register on your server.

### 2. Enable Two-Factor Authentication (2FA)
1. Log into `https://rdphiro.yourdomain.com`.
2. Click **My Account** (top-right).
3. Under **Two-Factor Authentication**, click **Set up Authenticator App** (TOTP).
4. Scan the QR code using Google Authenticator, 1Password, Bitwarden, or Authy.
5. Enter the 6-digit verification code. 2FA is now enforced on every login.

---

## 7. Backups & Disaster Recovery

All server state—including database records, registered agents, SSL certificates, encryption keys, and user settings—resides inside a single directory:
```
/opt/rdphiro/meshcentral-data/
```

### Manual Backup:
```bash
sudo tar -czvf /tmp/rdphiro-backup-$(date +%F).tar.gz /opt/rdphiro/meshcentral-data
```

### Automated Nightly Backup Cron Job:
Add a root cron job:
```bash
sudo crontab -e
```
Add this line to backup every night at 2:00 AM and keep the last 7 days:
```bash
0 2 * * * tar -czvf /var/backups/rdphiro-$(date +\%F).tar.gz /opt/rdphiro/meshcentral-data && find /var/backups -name "rdphiro-*.tar.gz" -mtime +7 -delete
```

To restore on any new server, simply install `rdphiro`, place your backup in `/opt/rdphiro/meshcentral-data`, and start the service. All your managed devices will reconnect automatically without reinstalling agents!

---

## 8. Optional: Using Nginx as a Reverse Proxy

> [!NOTE]
> If your Lightsail server is dedicated to `rdphiro`, you **do not need Nginx**. MeshCentral includes its own web server and automated Let's Encrypt engine.
>
> You only need Nginx if you are hosting **other websites or APIs** on the same server sharing port 80 and 443.

If you choose to use Nginx:

### 1. Update `config.json` for Nginx TLS Offload:
```json
{
  "settings": {
    "cert": "rdphiro.yourdomain.com",
    "port": 4430,
    "redirPort": 8080,
    "portBind": "127.0.0.1",
    "redirPortBind": "127.0.0.1",
    "tlsOffload": "127.0.0.1",
    "trustedProxy": "127.0.0.1"
  }
}
```
*(Remove the `"letsencrypt"` section from `config.json` because Nginx/Certbot handles the certificates.)*

### 2. Copy the Nginx Configuration:
Use the template at `nginx/rdphiro.conf`:
```bash
sudo cp /opt/rdphiro/nginx/rdphiro.conf /etc/nginx/sites-available/rdphiro.conf
sudo ln -s /etc/nginx/sites-available/rdphiro.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```
*(Crucial: The Nginx config includes `Upgrade $http_upgrade`, `Connection "upgrade"`, and `proxy_read_timeout 3600s` so WebSocket remote desktop streams do not get dropped).*

