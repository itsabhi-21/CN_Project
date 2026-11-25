## Summary
<!-- Describe what this PR changes and which Phase (Phase 1 / Phase 2) it belongs to. -->

## Mac Roles Affected
- [ ] Mac 1 — Primary DNS (`dnsmasq`) / Client (Abhinav Choudhary)
- [ ] Mac 2 — Edge `nginx` + TLS CA (Lakshya Yadav)
- [ ] Mac 3 — Backend A + Backup DNS / Standby Edge (Vaibhav)
- [ ] Mac 4 — Backend B + Capture / Diagnostics (Parv)

## Verification
- [ ] `./render.sh` succeeds without errors
- [ ] `bash tests/test_render.sh` passes
- [ ] `python3 -m unittest discover -s tests -v` passes
- [ ] No private keys (`*.key`) or `build/` artifacts staged
