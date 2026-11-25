# Contributors — CN Busters

This project is maintained by a 4-member Computer Networks team operating a 4-Mac private network service platform (`app.team1.test`).

## Team Roster & Machine Ownership

| Member | GitHub | Primary Role | Machine | Phase 1 Responsibilities | Phase 2 Responsibilities |
|---|---|---|---|---|---|
| **Abhinav Choudhary** | [@itsabhi-21](https://github.com/itsabhi-21) | Primary DNS + Client | **Mac 1** | `dnsmasq` primary resolver (`:53`), client DNS setup, DNS failure demos | Backup DNS coordination, live record updates (`dns-set-record.sh`), TTL testing |
| **Lakshya Yadav** | _add handle_ | Edge Reverse Proxy + TLS CA | **Mac 2** | Local Root CA (`mkcert` / OpenSSL), `nginx` TLS termination, HTTP/2 & round-robin LB | Passive health checks (`max_fails`, `fail_timeout`), `proxy_next_upstream` HA failover |
| **Vaibhav** | _add handle_ | Backend A + Standby Infra | **Mac 3** | Python REST Backend A (`:3001`), `/api/status` & `/api/catalog` testing | Backup `dnsmasq` resolver, standby `nginx` edge for DNS cutover (Ext E), `pf` isolation |
| **Parv** | _add handle_ | Backend B + Capture & Diagnostics | **Mac 4** | Python REST Backend B (`:3002`), caching verification (`304`), Wireshark `.pcap` captures | `ttl-watch.sh` cutover observation, `pf` isolation testing, layer-by-layer `diagnose.sh` |

## Local Git Setup (Per Team Member)

Each contributor should configure their real name and email before committing:

```bash
git config user.name "Your Name"
git config user.email "your-email@example.com"
```

Enable the repository's shared Conventional Commits hook:

```bash
git config core.hooksPath .githooks
```
