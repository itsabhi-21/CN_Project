# MAC 3 — Backend A (port 3001)  ·  Phase 2: Backup DNS + Standby edge

Tum **Mac 3** ho. Phase 1: Backend A. Phase 2: backup DNS + standby nginx bhi.
Poori team ka overview: `SETUP_4_MACS.md` · bahut detail: `FULL_GUIDE.md`.

## 0. Fresh Mac setup (ek baar, is Mac pe)

Terminal kholo (Cmd+Space → "Terminal") aur ek-ek line chalao:

```bash
# 1) Apple command line tools (python3, git, dig, curl) — popup aaye to Install
xcode-select --install

# 2) Homebrew (password maangega — typing dikhegi nahi, normal hai)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
brew --version            # version dikhe = OK   (Intel Mac pe path /usr/local hota hai — installer jo bole wahi lines chalao)

# 3) Zip ko Downloads mein unzip karo (double-click), phir:
cd ~/Downloads/MAC3
xattr -dr com.apple.quarantine .
chmod +x render.sh */*.sh
```

Wi-Fi: sab 4 Mac **same hotspot/router** pe. System Settings → Wi-Fi → (i) Details → **Private Wi-Fi address = Fixed**.
Firewall popup (python3 / nginx / dnsmasq "accept incoming connections?") aaye → **Allow**.

## 1. IP set karo (sirf `config.env`)

```bash
ipconfig getifaddr en0      # is Mac ki IP — team ke saath share karo
```
Charon IPs milne ke baad `config.env` kholo:
```bash
open -e config.env
```
Ye lines badlo aur save karo (charon Macs pe **bilkul same** file):
```
TEAM=team1
MAC1_IP=<Mac 1 ki IP>
MAC2_IP=<Mac 2 ki IP>
MAC3_IP=<Mac 3 ki IP>
MAC4_IP=<Mac 4 ki IP>
```
Phir:
```bash
./render.sh
scripts/netinfo.sh | tee evidence/phase1/A1-netinfo-$(hostname -s).txt
scripts/pingall.sh | tee evidence/phase1/A2-pingall-$(hostname -s).txt   # sab OK aane chahiye
```
> Neeche `team1` aur `<MACx_IP>` ki jagah apna team / IP likhna.
> IP baad mein badle → `config.env` update → `./render.sh` → apne role ka install command dobara.


## 2. PHASE 1 — order mein chalao

**Tum sabse pehle start karte ho** (Mac 4 ke saath).

```bash
# (a) Backend A chalao — ye terminal KHULA rakho
backend/run.sh A
#     band karna = Ctrl+C,  dobara = backend/run.sh A
```
Naya terminal tab (Cmd+T), same folder (`cd ~/Downloads/MAC3`):
```bash
curl -i http://localhost:3001/api/status     # X-Backend: A
```

**Mac 2 se `ca.crt` aane ke baad:**
```bash
mkdir -p tls/out && mv ~/Downloads/ca.crt tls/out/
tls/trust-ca.sh
```

### Failure demos (tum karoge)
- #3: Backend A terminal mein **Ctrl+C** → Mac 4 pe sab B → `backend/run.sh A`
- #4: Ctrl+C (Mac 4 bhi band kare) → Mac 4 pe 502 → dono restart

## 3. PHASE 2

```bash
# Ext A — Backup DNS (same records as Mac 1)
dns/install-dns.sh

# Ext B / E — DNS record change (Mac 1 ke saath SAME command)
scripts/dns-set-record.sh app <MAC3_IP>
scripts/dns-set-record.sh api <MAC3_IP>     # sirf Ext E mein
scripts/dns-set-record.sh app reset
scripts/dns-set-record.sh api reset

# Ext C — Firewall: sirf Mac 2 port 3001 pe aa sake
firewall/isolate.sh apply
firewall/isolate.sh status
firewall/isolate.sh rollback       # ⚠️ demo ke baad ZAROOR (Ext E se pehle)

# Ext D — Mac 2 bolega tab Ctrl+C backend, phir backend/run.sh A

# Ext E — Standby edge. Mac 2 se server.crt + server.key AirDrop se aayenge:
mv ~/Downloads/server.crt ~/Downloads/server.key tls/out/
nginx/install-edge.sh phase2
curl --resolve app.team1.test:443:<MAC3_IP> https://app.team1.test/edge-health   # test (kisi client se)
```
Note: Backend A (terminal 1) chalta rehna chahiye, baaki commands dusre tab mein.

## Band karna
```bash
# backend: Ctrl+C
sudo brew services stop dnsmasq
sudo nginx -s stop
firewall/isolate.sh rollback
```
