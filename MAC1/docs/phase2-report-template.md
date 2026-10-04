# Phase 2 Final Report — Team ____

## 1. What changed from Phase 1
(Short table: component, Phase 1 state, Phase 2 state, file changed.)

## 2. Resilience tests and results

| Test | Steps | Expected | Observed | Evidence file |
|---|---|---|---|---|
| Backup DNS (Ext A) | stop dnsmasq on Mac 1, `dig` from Mac 4 | answer from Mac 3 | | phase2/A-backup-dns.png |
| TTL change (Ext B) | change record, watch OS vs dig | old IP ≤30 s, flush = instant | | phase2/B-ttl-watch.png |
| Isolation (Ext C) | curl :3001 from client and from edge | client blocked, edge ok | | phase2/C-firewall.png |
| HA failover (Ext D) | stop A, lb-test, restart A | all B, then A/B | | phase2/D-ha-failover.png |
| Edge cutover (Ext E) | record → standby, two clients | fresh client moves first | | phase2/E-cutover.png |

## 3. Troubleshooting findings (Ext F)
Fault introduced · symptoms · layer-by-layer diagnosis (what each check showed) · root cause · fix · time taken.

## 4. Learning summary (one paragraph per extension)
**A — Backup DNS:**
**B — TTL:**
**C — Service isolation:**
**D — HA failover:**
**E — DNS cutover:**
**F — Troubleshooting:**

## 5. Remaining limitations
Single points of failure left, and what a production design would add.
