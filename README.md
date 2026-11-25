# CN Busters — Private Network Service Platform

A two-phase Computer Networks course project built on four physical macOS machines over a shared LAN — no cloud services and no pre-configured servers. A client resolves a private `.test` domain through the team's own DNS server, connects over verified HTTPS through a reverse proxy, and receives load-balanced responses from two Python REST backends with Phase 2 high-availability failover and firewall isolation.

**Team:** CN Busters  
**Members:** Abhinav Choudhary (Mac 1) · Lakshya Yadav (Mac 2) · Vaibhav (Mac 3) · Parv (Mac 4)

---

## Request Flow

```text
Client (Mac 4) ──UDP/53──▶ Primary/Backup DNS (Mac 1 / Mac 3)
               ──TCP/443 (TLS 1.3 + HTTP/2)──▶ Edge nginx (Mac 2 / Mac 3)
               ──HTTP (3001 / 3002)──▶ Backend A (Mac 3) / Backend B (Mac 4)
```

## Team Ownership

| Machine | Owner | Role | Services / Ports |
|---|---|---|---|
| **Mac 1** | **Abhinav Choudhary** | Primary DNS (`dnsmasq`) + Test Client | `dnsmasq` on `53/UDP+TCP` |
| **Mac 2** | **Lakshya Yadav** | Edge Reverse Proxy + TLS CA + Load Balancer | `nginx` on `80/TCP` (redirect), `443/TCP` (TLS, HTTP/2) |
| **Mac 3** | **Vaibhav** | Backend A · Phase 2: Backup DNS + Standby Edge | Python REST server `3001/TCP`, backup `dnsmasq`, standby `nginx` |
| **Mac 4** | **Parv** | Backend B + Test Client + Wireshark Capture | Python REST server `3002/TCP`, Wireshark, `diagnose.sh` |

## Repository Structure

```text
.
├── config.env                  # Single source of truth for team IPs, ports, interfaces
├── config.env.example          # Default template for config.env
├── render.sh                   # Renders *.tmpl into build/
├── backend/
│   ├── server.py               # Python stdlib REST backend (/, /api/status, /api/catalog, /api/metrics, /health)
│   └── run.sh                  # Launches Backend A or Backend B
├── dns/
│   ├── dnsmasq.conf.tmpl       # Private authoritative DNS for *.<TEAM>.test
│   ├── team.hosts.tmpl         # Host records (app, api, dns1, dns2, edge, backend-a, backend-b)
│   └── install-dns.sh          # Installs & restarts dnsmasq on Mac 1 (and Mac 3 in Phase 2)
├── nginx/
│   ├── edge-phase1.conf.tmpl   # Phase 1 TLS termination + round-robin load balancer
│   ├── edge-phase2.conf.tmpl   # Phase 2 passive health checks + proxy_next_upstream + /edge-health
│   └── install-edge.sh         # Installs & reloads nginx (`phase1` | `phase2`)
├── firewall/
│   ├── backend-pf.conf.tmpl    # Phase 2 macOS pf anchor rules isolating ports 3001/3002 to edge only
│   └── isolate.sh              # apply | status | rollback
├── tls/
│   ├── make-certs.sh           # Generates local Root CA + SAN server certificate
│   └── trust-ca.sh             # Installs/removes Root CA in macOS System keychain
├── scripts/
│   ├── lib.sh                  # Shared config & curl helpers
│   ├── netinfo.sh              # Host IP, subnet, gateway, MAC address
│   ├── pingall.sh              # Reachability check across all 4 Macs
│   ├── client-dns.sh           # Switch client resolver (primary | both | bogus | reset | flush)
│   ├── dns-set-record.sh       # Live DNS record update + SIGHUP reload
│   ├── lb-test.sh              # Round-robin / failover verification loop
│   ├── cache-demo.sh           # Demonstrates 200 vs ETag 304 conditional responses
│   ├── capture.sh              # tcpdump capture for Wireshark analysis
│   ├── ttl-watch.sh            # Compares OS resolver cache vs authoritative DNS TTL
│   └── diagnose.sh             # Layer-by-layer fault diagnosis (DNS -> IP -> TCP -> TLS -> HTTP)
├── tests/
│   ├── test_backend.py         # Unit tests for backend/server.py
│   └── test_render.sh          # Template rendering and shell syntax verification
├── docs/                       # Architecture doc, 4-Mac setup guide, full runbook, viva prep
├── evidence/                   # Captured Phase 1 & Phase 2 outputs and pcaps
├── reports/                    # Phase 1 and Phase 2 PDF reports
├── CONTRIBUTING.md             # Branch naming & Conventional Commits guide
└── CONTRIBUTORS.md             # Team roster & git setup
```

## Quick Start

1. **Configure team IPs** in `config.env` and render configs on every Mac:
   ```bash
   cp config.env.example config.env   # edit MAC1_IP..MAC4_IP
   ./render.sh
   ```
2. **Phase 1 startup order**:
   - Mac 3 (`Vaibhav`): `backend/run.sh A`
   - Mac 4 (`Parv`): `backend/run.sh B`
   - Mac 1 (`Abhinav`): `dns/install-dns.sh`
   - Mac 2 (`Lakshya`): `tls/make-certs.sh && nginx/install-edge.sh phase1`
   - Client Macs: copy `tls/out/ca.crt` (never `.key`), run `tls/trust-ca.sh`, then `scripts/client-dns.sh primary`
3. **Phase 2 extensions**:
   - **Ext A (Backup DNS):** Mac 3 runs `dns/install-dns.sh`; clients run `scripts/client-dns.sh both`
   - **Ext B (TTL cutover):** `scripts/ttl-watch.sh app` + `scripts/dns-set-record.sh`
   - **Ext C (Backend isolation):** Mac 3 & Mac 4 run `firewall/isolate.sh apply` (and `rollback` when done)
   - **Ext D & E (HA failover & standby edge):** Mac 2 & Mac 3 run `nginx/install-edge.sh phase2`
   - **Ext F (Fault diagnosis):** `scripts/diagnose.sh`

## Verification

```bash
python3 -m unittest discover -s tests -v
bash tests/test_render.sh
```

## Git Workflow

- Enable the Conventional Commits hook once after cloning:
  ```bash
  git config core.hooksPath .githooks
  ```
- See [CONTRIBUTING.md](CONTRIBUTING.md) and [CONTRIBUTORS.md](CONTRIBUTORS.md) for branch naming (`phase-1/*`, `phase-2/*`, `feat/*`, `fix/*`, `docs/*`) and commit guidelines.
- Previous repository history is preserved on the `archive/previous-work` branch.
