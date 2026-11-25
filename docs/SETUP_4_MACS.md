# 4 Mac Setup Guide — CN Project (Private Network Service Platform)

Har Mac ki apni zip hai (`MAC1.zip` … `MAC4.zip`). Har zip mein **pura project** hai
(scripts ek dusre pe depend karte hain + Phase 2 mein roles badalte hain), bas upar
`YOU_ARE_MAC_N.txt` batata hai ye kaunsa Mac hai. Pura detailed guide: `FULL_GUIDE.md`.

| Mac | Role | Kya chalega |
|---|---|---|
| **Mac 1** | Primary DNS + client | dnsmasq, dig, curl, browser |
| **Mac 2** | Edge (nginx, TLS, load balancer) | nginx, certificates |
| **Mac 3** | Backend A (port 3001) · Phase 2: backup DNS + standby edge | python backend, dnsmasq, nginx |
| **Mac 4** | Backend B (port 3002) + client + Wireshark capture | python backend, curl, Wireshark |

---

## STEP 0 — Sabhi 4 Mac pe (ek baar)

1. Sab Mac **ek hi Wi-Fi / phone hotspot** pe. (College Wi-Fi mein aksar Macs ek dusre ko ping nahi kar paate.)
2. System Settings → Wi-Fi → Details → **Private Wi-Fi address: Fixed** (taaki IP na badle).
3. Homebrew install (agar nahi hai): <https://brew.sh>
4. Zip unzip karo, Terminal mein folder ke andar jao:
   ```bash
   cd ~/Downloads/MAC1          # apna folder
   xattr -dr com.apple.quarantine .   # macOS "downloaded file" block hatao
   chmod +x render.sh */*.sh
   ```
5. Firewall popup aaye (python3 / nginx / dnsmasq) → **Allow**.

---

## STEP 1 — IP KAHAN CHANGE KARNI HAI  ⚠️ sabse important

**Sirf ek file: `config.env`.** Kahin aur IP mat likhna — scripts sab yahin se lete hain.

1. Har Mac pe apni IP nikaalo:
   ```bash
   ipconfig getifaddr en0                     # e.g. 192.168.43.25
   route -n get default | grep interface      # usually en0
   networksetup -listallnetworkservices       # usually "Wi-Fi"
   ```
2. Charon IPs ek jagah likho, phir `config.env` mein ye lines edit karo:
   ```bash
   TEAM=team1                 # apna team number -> app.team1.test
   MAC1_IP=192.168.1.11       # <- Mac 1 ki IP
   MAC2_IP=192.168.1.12       # <- Mac 2 ki IP
   MAC3_IP=192.168.1.13       # <- Mac 3 ki IP
   MAC4_IP=192.168.1.14       # <- Mac 4 ki IP
   NET_SERVICE="Wi-Fi"        # agar alag ho
   IFACE=en0                  # agar alag ho
   ```
   Port 443/80 bind na ho to: `HTTPS_PORT=8443`, `HTTP_PORT=8080`.
3. **Same `config.env` charon Macs pe copy karo** (AirDrop / WhatsApp / git). Charon mein bilkul same hona chahiye.
4. Har Mac pe:
   ```bash
   ./render.sh                # config.env se build/ mein real configs banata hai
   ```
5. `docs/architecture.md` ki IP table mein bhi apni real IPs bhar do (report ke liye).

> IP kabhi badal jaye (Wi-Fi reconnect) → `config.env` update → charon pe `./render.sh` → Mac 1 (aur Mac 3) pe `dns/install-dns.sh`, Mac 2 pe `nginx/install-edge.sh phase1` dobara.

---

## STEP 2 — Start karne ka ORDER

```
① Mac 3 + Mac 4: backends    ② Mac 1: DNS    ③ Mac 2: certs + nginx
④ ca.crt Mac 2 se sab Macs pe → trust    ⑤ Mac 1 + Mac 4: client DNS set    ⑥ test
```

### Mac 3 — Backend A
```bash
backend/run.sh A           # terminal khula rakho (0.0.0.0:3001)
```

### Mac 4 — Backend B
```bash
backend/run.sh B           # terminal khula rakho (0.0.0.0:3002)
```
Kisi bhi Mac se check: `curl -i http://<MAC3_IP>:3001/api/status` → `X-Backend: A`

### Mac 1 — Primary DNS
```bash
dns/install-dns.sh         # dnsmasq install + records load + self-test (Mac 2 ki IP print honi chahiye)
tail -f /tmp/dnsmasq.log   # (optional) live queries dekho
```

### Mac 2 — Certificates + Edge nginx
```bash
tls/make-certs.sh          # tls/out/ca.crt, server.crt, server.key banata hai
nginx/install-edge.sh phase1
tail -f /tmp/nginx-team-access.log   # (optional) har request ka upstream=
```
Ab **sirf `tls/out/ca.crt`** (`.key` kabhi nahi!) Mac 1, Mac 3, Mac 4 ke `tls/out/` folder mein copy karo (AirDrop).

### Har client Mac pe (Mac 1, Mac 4 — aur jo bhi browser use kare)
```bash
tls/trust-ca.sh            # CA ko System keychain mein trust karo (password maangega)
scripts/client-dns.sh primary   # DNS = Mac 1, cache flush
```

### Test (Mac 4 ya Mac 1 se)
```bash
dig app.team1.test                  # ANSWER = Mac 2 IP, SERVER = Mac 1
scripts/lb-test.sh 10               # A, B, A, B ...
```
Browser: `https://app.team1.test` → padlock, koi warning nahi.
curl cert error de to: `USE_CACERT=1 scripts/lb-test.sh 10` (ye bhi verify karta hai, `-k` nahi hai).

✅ Ye chal gaya = Phase 1 gate pass.

---

## STEP 3 — Har Mac ka Phase 1 kaam (evidence)

| Mac | Commands |
|---|---|
| **Sabhi** | `scripts/netinfo.sh \| tee evidence/phase1/A1-netinfo-$(hostname -s).txt` <br> `scripts/pingall.sh \| tee evidence/phase1/A2-pingall-$(hostname -s).txt` |
| **Mac 1** | `dig app.team1.test`, `nslookup app.team1.test` (screenshot) |
| **Mac 4** | `scripts/cache-demo.sh` (200 → 304) <br> `brew install --cask wireshark` <br> `scripts/capture.sh 1.2` aur `scripts/capture.sh 1.3` → `evidence/captures/*.pcap` Wireshark mein kholo, screenshot (filters: `dns`, `tcp.flags.syn==1`, `tls.handshake`) <br> `curl -v https://app.team1.test/api/status` |

**Phase 1 failure demos (Mac 4 se, har ek ke baad restore):**

| # | Break | Restore |
|---|---|---|
| 1 | Mac 4: `scripts/client-dns.sh bogus` → dig fail, ping Mac 2 chalega | `scripts/client-dns.sh primary` |
| 2 | Mac 1: `scripts/dns-set-record.sh app <MAC4_IP>`; Mac 4: `scripts/client-dns.sh flush` → Connection refused | Mac 1: `scripts/dns-set-record.sh app reset` |
| 3 | Mac 3: Ctrl+C → Mac 4: `scripts/lb-test.sh` sab B | Mac 3: `backend/run.sh A` |
| 4 | Mac 3 + Mac 4 dono backend band → `curl -v https://app.team1.test` → 502 | dono restart |
| 5 | Mac 4: `curl -v https://app.team1.test:8444/` → Connection refused | — |

---

## STEP 4 — Phase 2 (Mac wise)

| Ext | Mac | Commands |
|---|---|---|
| **A** Backup DNS | Mac 3 | `dns/install-dns.sh` |
| | Mac 1 + Mac 4 | `scripts/client-dns.sh both` |
| | Demo | Mac 1: `sudo brew services stop dnsmasq` → Mac 4: `scripts/client-dns.sh flush; dig app.team1.test` (SERVER = Mac 3) → Mac 1: `sudo brew services start dnsmasq` |
| **B** TTL | Mac 4 | Terminal 1: `scripts/ttl-watch.sh app` · Terminal 2: `curl -s https://app.team1.test/edge-health` |
| | Mac 1 **aur** Mac 3 | `scripts/dns-set-record.sh app <MAC3_IP>` → 30s mein OS column badlega · phir dono pe `scripts/dns-set-record.sh app reset` |
| **C** Firewall | Mac 3 + Mac 4 | `firewall/isolate.sh apply` → Mac 1 se `curl --connect-timeout 3 http://<MAC3_IP>:3001/health` timeout; `scripts/lb-test.sh 4` chalega → **`firewall/isolate.sh rollback`** (Ext E se pehle zaroori) |
| **D** HA failover | Mac 2 | `nginx/install-edge.sh phase2` → Mac 4: `scripts/lb-test.sh 6` → Mac 3 Ctrl+C → `lb-test` sab B → restart A, 10s wait → A/B wapas |
| **E** Edge cutover | Mac 3 | Mac 2 se `tls/out/server.crt` + `server.key` copy karo → `nginx/install-edge.sh phase2` |
| | Mac 4 | `scripts/ttl-watch.sh app` |
| | Mac 1 **aur** Mac 3 | `scripts/dns-set-record.sh app <MAC3_IP>` aur `scripts/dns-set-record.sh api <MAC3_IP>` → X-Edge Mac 3 ho jayega (Mac 4 pe ≤30s baad) → restore: dono pe `... reset` |
| **F** Fault diagnose | Mac 4 | `scripts/diagnose.sh` — jo pehla FAIL ho wahi layer kharab hai (DNS → ping → TCP → TLS → HTTP) |

Rule Phase 2: **DNS record change hamesha Mac 1 AUR Mac 3 dono pe.**

---

## Demo day — 30 min pehle checklist

- [ ] Sab Mac same Wi-Fi, `scripts/netinfo.sh` → IP same hai? Badli to STEP 1 dobara.
- [ ] Mac 3: `backend/run.sh A` · Mac 4: `backend/run.sh B`
- [ ] Mac 1: dnsmasq chalu (`dig @<MAC1_IP> app.team1.test`)
- [ ] Mac 2: `nginx/install-edge.sh phase2`
- [ ] Mac 3/4: `firewall/isolate.sh rollback` · DNS records `reset`
- [ ] Mac 4: `scripts/diagnose.sh` → sab PASS
- [ ] Viva: `docs/viva-prep.md` sab members padho

## Deliverables
- `docs/architecture.md` (IP table bharo → PDF) · `docs/phase2-report-template.md` bharo
- `evidence/` mein screenshots + `.pcap` (index: `evidence/README.md`)
- Code submit karte waqt **`.key` files mat daalna**.
