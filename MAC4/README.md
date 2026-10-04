# MAC 4 — Backend B (port 3002) + Test client + Wireshark capture

Tum **Mac 4** ho. Backend B chalate ho + main demo client ho (sab tests, captures, diagnose yahin se).
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
cd ~/Downloads/MAC4
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


```bash
# Wireshark bhi install karo (Task G ke liye)
brew install --cask wireshark
```

## 2. PHASE 1 — order mein chalao

**Tum sabse pehle start karte ho** (Mac 3 ke saath).

```bash
# (a) Backend B — ye terminal KHULA rakho
backend/run.sh B
```
Naya terminal tab (Cmd+T), `cd ~/Downloads/MAC4`, phir:
```bash
curl -i http://localhost:3002/api/status     # X-Backend: B
curl -i http://<MAC3_IP>:3001/api/status     # X-Backend: A
```

**Mac 1 DNS + Mac 2 nginx chalne aur `ca.crt` aane ke baad:**
```bash
mkdir -p tls/out && mv ~/Downloads/ca.crt tls/out/
tls/trust-ca.sh
scripts/client-dns.sh primary
scripts/client-dns.sh show
dig app.team1.test                 # SERVER = Mac 1
scripts/lb-test.sh 10              # A, B, A, B
open https://app.team1.test        # padlock
curl -v https://app.team1.test/api/status
curl -sI https://app.team1.test/ | head -1        # HTTP/2 200
```
curl certificate error de → aage har script `USE_CACERT=1` laga ke: `USE_CACERT=1 scripts/lb-test.sh 10`

```bash
# Task F — caching (200 -> 304)
scripts/cache-demo.sh

# Task G — packet capture (.pcap evidence/captures/ mein)
scripts/capture.sh 1.2
scripts/capture.sh 1.3
open -a Wireshark evidence/captures/
#   filters: dns | tcp.flags.syn==1 | tls.handshake | tls.record.content_type==23
#   Statistics -> Flow Graph -> screenshot
```

### Phase 1 failure demos (sab yahin se dikhte hain)
```bash
# 1 Wrong DNS server
scripts/client-dns.sh bogus
dig app.team1.test ; curl https://app.team1.test ; ping -c 2 <MAC2_IP>
scripts/client-dns.sh primary

# 2 Wrong record (Mac 1 pe dns-set-record.sh app <MAC4_IP> ke baad)
scripts/client-dns.sh flush ; curl -v https://app.team1.test     # Connection refused
# 3 Backend A band (Mac 3 Ctrl+C)
scripts/lb-test.sh 6                                              # sab B
# 4 Dono band (yahan bhi Ctrl+C on backend B)
curl -v https://app.team1.test/                                   # 502
backend/run.sh B                                                  # restore (backend tab mein)
# 5 Wrong port
curl -v https://app.team1.test:8444/                              # Connection refused
```

## 3. PHASE 2

```bash
# Ext A — Backup DNS
scripts/client-dns.sh both
#   (Mac 1 dnsmasq band kare)
scripts/client-dns.sh flush ; dig app.team1.test      # SERVER = Mac 3
scripts/lb-test.sh 4

# Ext B — TTL (Terminal 2 mein chalu rakho)
scripts/ttl-watch.sh app
#   Terminal 3:
curl -s https://app.team1.test/edge-health
#   (Mac 1 + Mac 3 record change karein) -> 30s mein OS column badlega
scripts/client-dns.sh flush                           # turant badlega

# Ext C — Firewall (backend B ke liye bhi)
firewall/isolate.sh apply
curl --connect-timeout 3 http://<MAC3_IP>:3001/health  # timeout
scripts/lb-test.sh 4                                    # edge se chalega
firewall/isolate.sh rollback                            # ⚠️ ZAROOR

# Ext D — HA
scripts/lb-test.sh 6    # A/B -> (Mac 3 Ctrl+C) -> sab B -> (restart, 10s) -> A/B

# Ext E — Cutover
scripts/ttl-watch.sh app       # X-Edge column Mac 2 -> 30s baad Mac 3

# Ext F — Faculty fault
scripts/diagnose.sh            # pehla FAIL = kharab layer; fix karke dobara
```

## Band karna / reset
```bash
# backend: Ctrl+C
firewall/isolate.sh rollback
scripts/client-dns.sh reset
```
