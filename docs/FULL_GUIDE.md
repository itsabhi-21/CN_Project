# Private Network Service Platform — Team Kit

Everything needed for both phases of the CN course project: backend code, dnsmasq / nginx / TLS / pf configs, scripts for every demonstration, and a step-by-step runbook. The app is deliberately tiny; the network is the project.

```
config.env            <- the ONLY file you edit (IPs, team id, ports)
render.sh             <- turns *.tmpl into real configs in build/
backend/server.py     <- REST backend (Python stdlib, no installs)
dns/                  <- dnsmasq config + record file + installer
nginx/                <- edge config Phase 1 and Phase 2 + installer
tls/                  <- make team CA + server cert, trust CA on clients
firewall/             <- pf rules for backend isolation (apply/rollback)
scripts/              <- netinfo, pingall, client-dns, lb-test, cache-demo,
                         capture, ttl-watch, dns-set-record, diagnose
docs/                 <- architecture doc, viva prep, Phase 2 report template
evidence/             <- put screenshots + .pcap files here (index inside)
```

Roles: **Mac 1** DNS + client · **Mac 2** edge nginx · **Mac 3** Backend A (Phase 2: backup DNS + standby edge) · **Mac 4** Backend B + client. A team of 2–3 can merge roles (e.g. Mac 2 runs Backend A too); just set the IPs accordingly in `config.env`.

---

## 0. Before you start (read this — it saves hours)

1. **Use a network you control** — a phone hotspot or a home router. Campus/lab Wi-Fi often has *client isolation* (machines can't reach each other); if `ping` between Macs fails on a working Wi-Fi, this is why.
2. **Keep IPs stable.** On each Mac: System Settings → Wi-Fi → Details → *Private Wi-Fi address: Fixed* (otherwise the MAC — and so the DHCP IP — can change). Optionally pin the IP: `sudo networksetup -setmanualwithdhcprouter Wi-Fi 192.168.x.y`.
3. **Install tools**: Homebrew on every Mac; the install scripts run `brew install dnsmasq` / `brew install nginx` on the machines that need them. Add Wireshark (`brew install --cask wireshark`) on the capture machine. `python3`, `curl`, `dig`, `openssl`, `nc`, `tcpdump` ship with macOS (run `xcode-select --install` if `python3` asks).
4. **macOS Application Firewall**: if it's on, click *Allow* when python3 / nginx / dnsmasq ask to accept incoming connections.
5. Put this folder on **every** Mac at the same path (GitHub clone is easiest). Run all commands from the folder root.

## 1. Configure once

```bash
# on each Mac, find its IP and interface
ipconfig getifaddr en0
route -n get default | grep interface
networksetup -listallnetworkservices      # usually "Wi-Fi"
```

Edit `config.env` (team id + four IPs), commit/copy it to all Macs, then on every Mac:

```bash
chmod +x render.sh */*.sh
./render.sh
```

If you can't bind 443/80, set `HTTPS_PORT=8443`, `HTTP_PORT=8080` (Homebrew's default nginx server already uses 8080 — then comment out that `server {}` block in `$(brew --prefix)/etc/nginx/nginx.conf`).

---

## PHASE 1 — Build & Observe

### Task A — Private LAN (all Macs)

```bash
scripts/netinfo.sh  | tee evidence/phase1/A1-netinfo-$(hostname -s).txt
scripts/pingall.sh  | tee evidence/phase1/A2-pingall-$(hostname -s).txt
```

Fill the IP table and topology in `docs/architecture.md` (Mermaid diagram already drawn).

### Task B — Private DNS (Mac 1)

```bash
dns/install-dns.sh                        # installs dnsmasq, loads records, self-tests
```

Records created (`dns/team.hosts.tmpl`): `app.teamX.test` and `api.teamX.test` → Mac 2, plus helper names. TTL is 30 s. Any other `*.teamX.test` name returns NXDOMAIN; other internet names are forwarded to `UPSTREAM_DNS`.

On **at least two client Macs** (Mac 1 and Mac 4):

```bash
scripts/client-dns.sh primary             # sets DNS = Mac 1, flushes cache
dig app.team1.test                        # look for: ANSWER 192.168.1.12, SERVER: <Mac1>#53
nslookup app.team1.test
```

On Mac 1 itself the setting points at its own LAN IP; that's fine. Watch queries arriving live: `tail -f /tmp/dnsmasq.log`.

Explain: DNS only turns a *name into an IP*. No connection to the service has happened yet; TCP + TLS + HTTP come afterwards, to whatever IP DNS returned.

### Task C — Backends (Mac 3 and Mac 4)

```bash
backend/run.sh A        # Mac 3  -> 0.0.0.0:3001
backend/run.sh B        # Mac 4  -> 0.0.0.0:3002
```

Test directly from another Mac (this works only until Phase 2 Ext C blocks it):

```bash
curl -i http://192.168.1.13:3001/api/status
curl -i http://192.168.1.14:3002/api/status
```

Endpoints: `/` (HTML), `/api/status` (JSON with backend id), `/api/catalog` (cacheable, ETag), `/health`. Every response has `X-Backend: A|B`. The server binds `0.0.0.0` — binding to `127.0.0.1` would make it reachable only from the same Mac (a classic injected fault).

### Task E (do it before D) — TLS certificate (Mac 2)

```bash
tls/make-certs.sh       # creates tls/out/ca.crt, ca.key, server.crt, server.key
```

This makes a **private Certificate Authority** and a server certificate for `app` + `api.teamX.test` (SAN, `serverAuth`, 397-day validity — all required by macOS). Copy **only `tls/out/ca.crt`** to every client Mac (AirDrop/scp/git), then on each client:

```bash
tls/trust-ca.sh                           # adds the CA to the System keychain
```

Safari/Chrome now trust the site. Firefox: Settings → Privacy & Security → Certificates → Import `ca.crt`. If `curl` still complains, run scripts with `USE_CACERT=1` (passes `--cacert`, which *still validates* the chain — allowed; `-k` is not).

### Task D — Edge reverse proxy + load balancer (Mac 2)

```bash
nginx/install-edge.sh phase1              # installs nginx, copies cert, tests, starts
```

From a client:

```bash
scripts/lb-test.sh 10                     # A, B, A, B ... via X-Backend
curl -sI https://app.team1.test/ | grep -i -E 'HTTP/|x-'
```

The config (`nginx/edge-phase1.conf.tmpl`) has an `upstream` pool (round robin), an HTTP→HTTPS redirect, TLS termination, `X-Forwarded-*` headers, and debug headers `X-Edge` (which edge) and `X-Upstream` (which backend IP:port). Logs: `tail -f /tmp/nginx-team-access.log` on Mac 2 shows `upstream=` per request.

Why the client never needs backend IPs: DNS only publishes the edge; nginx holds the backend list privately and opens its *own* TCP connection to a backend. Look at `/api/status` → `tcp_peer_ip` is Mac 2, while `x_forwarded_for` is the real client.

HTTP/2: `curl -sI https://app.team1.test/ | head -1` shows `HTTP/2 200` (negotiated via ALPN in TLS). Force 1.1: `curl --http1.1 -sI ...`.

### Task F — Caching

```bash
scripts/cache-demo.sh
```

Shows `Cache-Control: public, max-age=60` and `ETag`, a full 200 with body, a conditional `If-None-Match` → **304 Not Modified** with 0 body bytes, and a stale ETag → 200. For a **fresh cache hit**, open `https://app.team1.test/api/catalog` in Chrome, DevTools → Network, visit it again within 60 s by pressing Enter in the address bar: Size shows *(disk cache)* and no request reaches the server (check the nginx log — nothing new).

Three cases to explain: fresh hit (no network at all), conditional request (network round trip, but only headers come back — 304), full request (200 + whole body).

Both backends compute the same ETag for the same content, so a conditional request still gets 304 even when load balancing switches backend.

### Task G — Full protocol capture (on Mac 4)

```bash
scripts/capture.sh 1.2      # TLS 1.2: Certificate message visible in clear
scripts/capture.sh 1.3      # TLS 1.3: only ClientHello/ServerHello in clear
```

Each flushes the DNS cache (so a real query happens), records `udp/53` + `tcp/443` to `evidence/captures/*.pcap`, and makes one request. Open in Wireshark and screenshot each layer:

| Show | Wireshark filter | Point out |
|---|---|---|
| DNS | `dns` | query `A app.team1.test` → response with Mac 2 IP; client ephemeral port → **53/UDP** |
| TCP handshake | `tcp.flags.syn==1` then follow the stream | SYN → SYN-ACK → ACK; client ephemeral port → **443/TCP**; the socket pair (4-tuple) |
| TLS | `tls.handshake` | ClientHello (SNI = app.team1.test, ALPN h2), ServerHello, Certificate (1.2 capture), ChangeCipherSpec, Finished |
| Encrypted data | `tls.record.content_type==23` | Application Data — HTTP headers are inside, unreadable |
| Seq/Ack | any TCP packet → Transmission Control Protocol | relative seq/ack numbers growing by bytes sent |
| Whole flow | Statistics → Flow Graph | ladder diagram for the report |

Also screenshot `curl -v https://app.team1.test/api/status` — the client *can* see the HTTP headers because it holds the session keys; Wireshark can't. (Optional: `SSLKEYLOGFILE=~/keys.log` with Chrome lets Wireshark decrypt — a good bonus.)

### Phase 1 — Required failure demonstrations

Run from a client (Mac 4); restore after each one.

| # | Break it | Observe | Restore |
|---|---|---|---|
| 1 | Wrong DNS server: `scripts/client-dns.sh bogus` | `dig app.team1.test` times out, `curl` → *Could not resolve host*, **but** `ping <Mac2 IP>` works → DNS and IP are independent layers | `scripts/client-dns.sh primary` |
| 2 | Wrong record (on Mac 1): `scripts/dns-set-record.sh app <Mac4 IP>`, then on client `scripts/client-dns.sh flush` | `dig` succeeds with the wrong IP; `curl` → *Connection refused* (nothing on 443 at Mac 4) → DNS is a directory, not a connection | `scripts/dns-set-record.sh app reset` |
| 3 | Stop Backend A (Ctrl+C on Mac 3) | `scripts/lb-test.sh` → all B, all 200 (nginx retries the other server by default) | `backend/run.sh A` |
| 4 | Stop both backends | `curl -v`: DNS ok, TCP ok, TLS ok, then **502 Bad Gateway** → the edge works, the failure is behind it | restart both |
| 5 | Wrong port: `curl -v https://app.team1.test:8444/` | *Connection refused*; in Wireshark SYN → **RST**. Host reachable, port closed → IP address and port are separate identifiers | — |

---

## PHASE 2 — Harden & Recover

### Ext A — Backup DNS (Mac 3)

```bash
dns/install-dns.sh                        # on Mac 3: identical config + records
dig @192.168.1.13 app.team1.test          # from a client, prove it answers
scripts/client-dns.sh both                # on clients: Mac 1 then Mac 3
```

Demo: on Mac 1 `sudo brew services stop dnsmasq`. On Mac 4: `scripts/client-dns.sh flush; dig app.team1.test` — dig prints a timeout against Mac 1, then `SERVER: 192.168.1.13#53` with the answer; `scripts/lb-test.sh 4` still works (first lookup may take ~1–2 s while the OS gives up on Mac 1). Restart: `sudo brew services start dnsmasq`.

DNS failure vs application failure: DNS down → *Could not resolve host* (we never learn the IP; no TCP at all). Backend down → name resolves, TCP+TLS succeed, nginx returns 502.

**Rule from now on:** every record change must be run on **both** DNS servers.

### Ext B — TTL and controlled record change

Terminal 1 on Mac 4: `scripts/ttl-watch.sh app` (prints, every 3 s, what the **OS cache** returns vs what the **DNS server** returns now, plus TTL).

```bash
curl -s https://app.team1.test/edge-health        # Mac 4: prime the OS cache
# Mac 1 AND Mac 3:
scripts/dns-set-record.sh app 192.168.1.13
```

You'll see `dig` (which bypasses the OS cache and asks the server) change instantly, while the OS-resolver column keeps the old IP for up to 30 s, then switches. Repeat, and this time run `scripts/client-dns.sh flush` → the OS column changes immediately. Finally `scripts/dns-set-record.sh app reset` on both servers.

Production link: before a migration, operators lower the TTL (e.g. 3600 → 60) a day ahead, so that at cutover time every cache expires within a minute; after it's stable, they raise it again. Long TTL = fewer queries, slower changes.

Note: `dig` against a local-records dnsmasq always shows TTL 30 (it's authoritative, not counting down); the count-down happens in the client's cache.

### Ext C — Service isolation with pf (Mac 3 and Mac 4)

```bash
firewall/isolate.sh apply      # saves /etc/pf.conf backup, loads anchor rules
firewall/isolate.sh status
```

Rules (`firewall/backend-pf.conf.tmpl`): allow 3001/3002 **only from Mac 2**, allow loopback, drop everything else to those ports. They are loaded into the anchor `com.apple/team-isolation`, which macOS's stock `/etc/pf.conf` already evaluates — so the system file is never edited.

Demo from Mac 1 or Mac 4:

```bash
curl --connect-timeout 3 http://192.168.1.13:3001/health   # times out (dropped)
scripts/lb-test.sh 4                                          # via edge: still 200
```

On Mac 2: `curl http://192.168.1.13:3001/health` → `ok`. Explain *drop* (timeout, attacker learns nothing) vs *return* (immediate RST). Then:

```bash
firewall/isolate.sh rollback
```

Roll back (or uncomment the standby line and re-render) **before Ext E**, because the standby edge on Mac 3 must reach Backend B on Mac 4.

### Ext D — HA failover (Mac 2)

```bash
nginx/install-edge.sh phase2
```

Adds passive health checking: `max_fails=1 fail_timeout=10s`, fast `proxy_connect_timeout 2s`, and `proxy_next_upstream error timeout http_502 http_503 http_504` so a failed attempt is retried on the other backend invisibly, plus `/edge-health`.

Demo: `scripts/lb-test.sh 6` (A/B) → Ctrl+C Backend A → `scripts/lb-test.sh 6` (all B, all 200) → `backend/run.sh A` → wait ~10 s → `scripts/lb-test.sh 6` (A/B again). Show `tail /tmp/nginx-team-access.log` on Mac 2: failed attempts appear as `upstream=A, B`.

Open-source nginx does *passive* checks (detects failure on real traffic). Active probing needs nginx Plus, HAProxy, or a cloud LB's health check — mention this.

**Remaining single point of failure:** the edge (Mac 2) — and the LAN/Wi-Fi router itself. Fixes: two edges sharing a floating virtual IP via VRRP/keepalived (seconds failover); or multiple A records / health-checked DNS failover (Route 53 failover routing); in cloud, a managed LB that is itself redundant across availability zones; anycast for global edges.

### Ext E — DNS-based edge cutover (standby edge on Mac 3)

On Mac 3 (with firewall rolled back): copy `tls/out/server.crt` + `server.key` from Mac 2 into `tls/out/`, then

```bash
nginx/install-edge.sh phase2               # same config, same cert
```

Test the standby *without* touching DNS (from a client):

```bash
curl --resolve app.team1.test:443:192.168.1.13 https://app.team1.test/edge-health
```

Cutover:

1. Mac 4: start `scripts/ttl-watch.sh app` (X-Edge column = Mac 2's hostname).
2. Mac 1: `scripts/client-dns.sh flush` (simulates a "new" client).
3. Mac 1 **and** Mac 3: `scripts/dns-set-record.sh app 192.168.1.13` (and `api` too).
4. Mac 1 immediately: `curl -sI https://app.team1.test/ | grep -i x-edge` → **Mac 3** (fresh lookup).
5. Mac 4 keeps showing **Mac 2** until its cached answer expires (≤30 s), then flips to Mac 3.
6. Once all traffic is on the standby, stop the old edge: `sudo nginx -s stop` on Mac 2. This is the real reason TTL matters — stopping the old edge before caches expire would cause errors for cached clients.
7. Restore: records → `reset` on both DNS servers, restart nginx on Mac 2.

### Ext F — Faculty-injected fault

Run `scripts/diagnose.sh` from a client and narrate each layer. It checks: DNS servers individually and the OS resolver; is the IP actually an edge; ping; TCP connect to 443; TLS chain/expiry/SAN; HTTP status and which backend answered.

Likely faults and where they show up:

| Symptom | Layer | Likely cause → fix |
|---|---|---|
| *Could not resolve host*, `dig @Mac1` times out | DNS | dnsmasq stopped → `sudo brew services start dnsmasq` |
| `dig @Mac1` fine, OS resolver fails | DNS (client) | client DNS settings changed → `scripts/client-dns.sh primary` |
| resolves to wrong IP | DNS data | bad record in `team.hosts` → `dns-set-record.sh app reset` |
| ping fails | IP / link | Mac off Wi-Fi, IP changed (DHCP), wrong network |
| TCP refused on 443 | Transport | nginx stopped / listening on other port → `sudo nginx`, `sudo lsof -iTCP -sTCP:LISTEN -n -P` |
| TCP times out | Transport | pf / firewall dropping → `sudo pfctl -s info`, `firewall/isolate.sh status` |
| cert error: name mismatch / expired / unknown CA | TLS | wrong cert in nginx, CA removed from keychain, system clock wrong → `date`, `openssl x509 -noout -dates` |
| 502 Bad Gateway | Edge → backend | backend down, wrong upstream IP/port, backend bound to 127.0.0.1, pf blocking edge → check `/tmp/nginx-team-error.log` |
| 504 Gateway Timeout | Edge → backend | backend hung or packets dropped |
| 404 | Application | wrong path / location block |
| only A or only B ever answers | LB config | a server commented out / marked `down` in upstream |

Method to say out loud: *"Bottom-up along the request: first can I get the IP? Then can I reach the host? Then is the port open? Then does TLS verify? Then what does the application answer? The first step that fails is the faulty layer."*

---

## Final demonstration — 11-step runbook

| # | Who / where | Command / action |
|---|---|---|
| 1 | Laptop with docs | Open `docs/architecture.md` (topology, IP table, service map) |
| 2 | Each Mac | `scripts/netinfo.sh` then `scripts/pingall.sh` |
| 3 | Mac 4 | `scripts/client-dns.sh show` then `dig app.team1.test` (SERVER line = Mac 1) |
| 4 | Mac 4 | Browser → `https://app.team1.test` (padlock, no warning, click cert → issuer = team CA) |
| 5 | Mac 4 | `scripts/lb-test.sh 10` |
| 6 | Mac 4 | Open saved `evidence/captures/flow-tls1.2-*.pcap`, walk DNS → SYN/SYN-ACK/ACK → TLS → App Data |
| 7 | Mac 4 | `scripts/cache-demo.sh` (+ DevTools disk-cache) |
| 8 | Mac 3 + Mac 4 | Ctrl+C Backend A → `scripts/lb-test.sh 6` → restart → resumes |
| 9 | Mac 1 + Mac 4 | Stop primary DNS → still resolves; then TTL watch / cutover |
| 10 | Mac 4 | `scripts/diagnose.sh`, fix, re-run |
| 11 | Everyone | Viva — study `docs/viva-prep.md` |

**30 minutes before:** all Macs on the same network, IPs unchanged (`scripts/netinfo.sh`; if changed, update `config.env`, `./render.sh`, reinstall DNS records + nginx), backends running, `scripts/diagnose.sh` all PASS, firewall rolled back, DNS records `reset`, terminals pre-opened.

## Deliverables checklist

- [ ] Architecture document — `docs/architecture.md` (fill IP table, export to PDF)
- [ ] Configuration bundle — `dns/`, `nginx/`, `tls/` (no `.key` files!), `firewall/`, and this README
- [ ] Backend source — `backend/` (push repo to GitHub)
- [ ] Evidence folder — `evidence/` (see `evidence/README.md`)
- [ ] Phase 2 report — `docs/phase2-report-template.md`
- [ ] Every member can explain every row of `docs/viva-prep.md`
