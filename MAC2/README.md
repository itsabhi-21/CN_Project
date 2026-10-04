# MAC 2 — Edge: nginx reverse proxy + TLS + load balancer

Tum **Mac 2** ho. Saari HTTPS traffic tumhare paas aati hai aur tum Mac 3 / Mac 4 ko bhejte ho.
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
cd ~/Downloads/MAC2
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

**Start order team ka:** Mac 3 + Mac 4 backend → Mac 1 DNS → **Mac 2 (tum)** → certificate share.

```bash
# (a) Certificates banao (sirf EK baar, sirf Mac 2 pe)
tls/make-certs.sh
ls tls/out                     # ca.crt  ca.key  server.crt  server.key ...

# (b) Backends tak pahunch check
curl http://<MAC3_IP>:3001/health      # ok
curl http://<MAC4_IP>:3002/health      # ok

# (c) nginx install + start  (password maangega)
nginx/install-edge.sh phase1

# (d) Live log — har request ka upstream= dikhega
tail -f /tmp/nginx-team-access.log
```

**(e) Certificate share karo:** Finder → `tls/out/ca.crt` → AirDrop to Mac 1, Mac 3, Mac 4.
❌ `ca.key` / `server.key` kisi ko mat bhejna (exception: Phase 2 Ext E mein Mac 3 ko `server.crt` + `server.key`).

Port 443 error aaye → `config.env` mein `HTTPS_PORT=8443`, `HTTP_PORT=8080` (charon Macs pe) → `./render.sh` → `nginx/install-edge.sh phase1`.

Agar is Mac pe bhi browser se test karna hai:
```bash
tls/trust-ca.sh
scripts/client-dns.sh primary
scripts/lb-test.sh 10
```

## 3. PHASE 2

```bash
# Ext D — HA failover config
nginx/install-edge.sh phase2
tail -f /tmp/nginx-team-access.log      # Backend A band ho to: upstream=A, B dikhega

# Ext C demo — sirf Mac 2 backends tak pahunch sakta hai
curl http://<MAC3_IP>:3001/health        # ok (Mac 1/4 se timeout hoga)

# Ext E — Mac 3 ko cert files bhejo (AirDrop):  tls/out/server.crt  tls/out/server.key
# cutover ke baad (sab traffic Mac 3 pe):
sudo nginx -s stop
# restore:
sudo nginx
```

## Band karna / restart
```bash
sudo nginx -s stop        # band
sudo nginx                # chalu
sudo nginx -t             # config check
tail /tmp/nginx-team-error.log    # 502 aaye to yahan dekho
```
