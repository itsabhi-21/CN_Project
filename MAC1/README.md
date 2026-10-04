# MAC 1 — Primary DNS server + Test client

Tum **Mac 1** ho. Kaam: dnsmasq (DNS server) chalana + client ki tarah test karna.
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
cd ~/Downloads/MAC1
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

**Start order team ka:** Mac 3 + Mac 4 backend → **Mac 1 DNS (tum)** → Mac 2 nginx → certificate share.

```bash
# (a) DNS server install + start  (dnsmasq install karega, password maangega)
dns/install-dns.sh
#     last mein Mac 2 ki IP print honi chahiye = OK

# (b) Is Mac ka DNS bhi Mac 1 pe set karo
scripts/client-dns.sh primary

# (c) Check
dig app.team1.test          # ANSWER = Mac 2 IP, SERVER = Mac 1 IP#53
nslookup app.team1.test
tail -f /tmp/dnsmasq.log    # live queries (Ctrl+C se band)
```

**Mac 2 se `ca.crt` milne ke baad** (AirDrop se aayegi) usko `tls/out/` folder mein rakho:
```bash
mkdir -p tls/out && mv ~/Downloads/ca.crt tls/out/
tls/trust-ca.sh             # browser/curl ab certificate trust karenge
scripts/lb-test.sh 10       # A, B, A, B ...
open https://app.team1.test # padlock, koi warning nahi
```
Screenshot: `dig`, `nslookup`, browser padlock → `evidence/phase1/`.

### Failure demo #2 (tum karoge)
```bash
scripts/dns-set-record.sh app <MAC4_IP>     # galat record
#   Mac 4: scripts/client-dns.sh flush; curl -v https://app.team1.test  -> Connection refused
scripts/dns-set-record.sh app reset         # wapas theek
```

## 3. PHASE 2

```bash
# Ext A — Backup DNS demo (Mac 3 pe backup DNS install hone ke baad)
scripts/client-dns.sh both               # DNS = Mac 1 + Mac 3
sudo brew services stop dnsmasq          # primary band  -> Mac 4 abhi bhi resolve karega
sudo brew services start dnsmasq         # wapas chalu

# Ext B — TTL demo (Mac 3 pe bhi SAME command saath mein)
scripts/dns-set-record.sh app <MAC3_IP>
scripts/dns-set-record.sh app reset

# Ext E — Edge cutover (Mac 3 pe bhi same)
scripts/client-dns.sh flush
scripts/dns-set-record.sh app <MAC3_IP>
scripts/dns-set-record.sh api <MAC3_IP>
curl -sI https://app.team1.test/ | grep -i x-edge     # -> Mac 3
scripts/dns-set-record.sh app reset
scripts/dns-set-record.sh api reset

# Ext C demo — direct backend access block hona chahiye
curl --connect-timeout 3 http://<MAC3_IP>:3001/health   # timeout = firewall kaam kar raha
```
⚠️ Phase 2 rule: DNS record change **Mac 1 aur Mac 3 dono** pe.

## Band karna / reset
```bash
sudo brew services stop dnsmasq
scripts/client-dns.sh reset      # is Mac ka DNS wapas normal
```
