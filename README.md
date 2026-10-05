# CN Busters — Private Network Service Platform

A two-phase Computer Networks course project: a small private service environment built entirely on local hardware — no cloud, no pre-configured servers. A client resolves a private domain name through our own DNS server, connects over verified HTTPS through a reverse proxy, and gets load-balanced responses from two backend servers.

**Course:** Computer Networks — Course Project
**Team:** CN Busters
**Members:** Abhinav Choudhary (2401020080) · Lakshya Yadav (2401010253)
**Infrastructure:** 4 physical macOS laptops on one shared LAN (Type 1 — no cloud)

---

## What this project demonstrates

A single client request travels through every layer of the networking stack we've studied in class:

```
Client → DNS lookup (Mac 1) → HTTPS request (Mac 2 / nginx) → Backend A or B (Mac 3 / Mac 4)
```

Along the way we prove, with captured evidence, that DNS, TCP, TLS, HTTP, caching, and load balancing each do their job.

---

## Team network

| Mac | Role | IP (en0) | Services / ports |
|---|---|---|---|
| Mac 1 | Private DNS server (dnsmasq) + test client | `10.7.21.254` | dnsmasq, port 53 |
| Mac 2 | Edge reverse proxy + load balancer | `10.7.34.29` | nginx — 80 (redirects), 443 (TLS, HTTP/2) |
| Mac 3 | Backend A | `10.7.5.55` | Python REST server, port 3001 |
| Mac 4 | Backend B + test client | `10.7.15.107` | Python REST server, port 3002 |

- Network: `10.7.0.0/19`, gateway `10.7.0.1`
- Private domain: `app.team1.test` → Mac 2 (resolved only through our own DNS, never `.local`)
- Client never contacts a backend directly — every request goes through the edge (Mac 2)

---

## Stack

- **DNS:** dnsmasq
- **Edge / load balancer:** nginx 1.31.6 (round-robin, TLS termination, HTTP/2)
- **TLS:** Local OpenSSL certificate authority (`team1 Local Root CA`) — no self-signed browser warnings, no `-k` flag
- **Backends:** Python REST servers (stdlib HTTP), one process per Mac, bound to `0.0.0.0`
- **Tooling:** curl, dig, Wireshark, `nc`
- **Config management:** all machine IPs live in `config.env`; `./render.sh` generates the dnsmasq, nginx, and firewall configs from it

---

## Repository structure

```
.
├── config.env                  # single source of truth for all Mac IPs
├── render.sh                   # generates configs below from config.env
├── scripts/
│   ├── netinfo.sh               # prints this machine's IP/mask/gateway/MAC
│   └── pingall.sh               # pings all four team Macs, reports loss
├── backend/
│   └── run.sh                   # starts the Python backend — usage: run.sh A | B
├── build/
│   ├── dns/
│   │   ├── dnsmasq.conf
│   │   └── team.hosts
│   ├── nginx/
│   │   ├── edge-phase1.conf
│   │   └── edge-phase2.conf
│   └── firewall/
│       └── backend-pf.conf
└── evidence/
    └── phase1/                  # captured command output, screenshots, pcaps
```

---

## Prerequisites (per machine)

```bash
brew install dnsmasq nginx mkcert wireshark
```

- Admin access required on the DNS machine (Mac 1) and the edge machine (Mac 2)
- Python 3 (stdlib only — no extra packages needed for the backends)
- All four machines on the same Wi-Fi/LAN segment, with client isolation **disabled** (use a phone hotspot if the lab Wi-Fi isolates clients from each other)

---

## Setup — Phase 1

Run on every machine first, to confirm the network layer is sound before configuring any service:

```bash
scripts/netinfo.sh | tee evidence/phase1/A1-netinfo-$(hostname -s).txt
scripts/pingall.sh | tee evidence/phase1/A2-pingall-$(hostname -s).txt
```

All pairs should show **0% packet loss**. If not, fix connectivity before continuing.

**1. Generate configs from `config.env`**

```bash
./render.sh
```

This renders `dnsmasq.conf`, `team.hosts`, `edge-phase1.conf`/`edge-phase2.conf`, and `backend-pf.conf` into `build/`.

**2. DNS (Mac 1 only)**

```bash
brew services start dnsmasq
dig app.team1.test            # should resolve to Mac 2's IP
dig @8.8.8.8 app.team1.test   # should NXDOMAIN — proves it's private
```

Set Mac 1 (`10.7.21.254`) as the DNS resolver on every other Mac: **System Settings → Network → DNS**.

**3. Backends (Mac 3 and Mac 4)**

```bash
backend/run.sh A   # on Mac 3, port 3001
backend/run.sh B   # on Mac 4, port 3002
```

Verify from another Mac:

```bash
curl -i http://10.7.5.55:3001/api/status
```

**4. Edge + load balancer (Mac 2)**

```bash
brew services start nginx
```

Verify round-robin:

```bash
for i in {1..6}; do curl -s https://app.team1.test/api/status; echo; done
```

Responses should alternate `A` and `B` in the `X-Backend` header.

**5. HTTPS**

```bash
mkcert -install
mkcert app.team1.test
```

Trust the generated root CA (`mkcert -CAROOT`) on every client Mac via Keychain Access → **Always Trust**. Verify with:

```bash
curl -v https://app.team1.test
```

No certificate warnings, no `-k` flag, TLS 1.3 negotiated.

**6. Caching**

```bash
curl -sI https://app.team1.test/api/catalog     # Cache-Control: public, max-age=60
curl -sI https://app.team1.test/api/status       # Cache-Control: no-store
```

**7. Packet capture**

Open Wireshark on a client Mac, capture on `en0`, then trigger a request:

```bash
dig app.team1.test
curl -v https://app.team1.test/api/status
```

Filter and save evidence for: `dns`, `tcp.flags.syn==1`, `tls.handshake`.

---

## Failure demonstrations (Phase 1)

| Scenario | How to trigger | Expected result |
|---|---|---|
| One backend down | `Ctrl+C` on `backend/run.sh A` (Mac 3) | All requests now show `X-Backend: B`; service stays up |
| Wrong DNS server | `dig @8.8.8.8 app.team1.test` | NXDOMAIN, but `ping` to the IP still works |
| Wrong destination port | `curl -v https://app.team1.test:8989/api/status` | Connection refused; `ping` to the host still succeeds |

Each scenario isolates a different layer — application, DNS, and transport — while the layers underneath keep working.

---

## Phase 2 (extensions, in progress)

- Backup DNS resolver with automatic client failover
- DNS TTL / controlled record cutover
- Backend firewall rules restricting direct access to ports 3001/3002 (edge-only)
- nginx health-check-based failover between backends
- Faculty-injected troubleshooting challenge

See `build/firewall/backend-pf.conf` and `build/nginx/edge-phase2.conf` for the in-progress configuration.

---

## Evidence checklist

- [x] `netinfo` + `pingall` output — Task A
- [x] `dig` output from private and public resolvers — Task B
- [x] Direct `curl` to both backends showing `X-Backend` headers — Task C
- [x] Six-request round-robin output — Task D
- [x] `curl -v` TLS handshake output — Task E
- [x] Cache header + 304 output — Task F
- [x] Wireshark captures: DNS, TCP handshake, TLS handshake — Task G
- [x] All three failure demonstrations — Task G

---

## Team notes

- Keep all four laptops' hostnames and IPs in `config.env` — never hardcode an IP directly in `dnsmasq.conf` or `edge-*.conf`; re-run `./render.sh` after any change.
- Private keys for the local CA stay on Mac 2 only; only `ca.crt` is distributed and trusted on client machines.
- Domain suffix is `.test`, never `.local` (conflicts with macOS mDNS).
