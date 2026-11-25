# Contributing & Git Workflow

## Branching Conventions

- `main` — stable, verified releases for completed phases.
- `phase-1/<topic>` — Phase 1 core platform work (DNS, TLS, nginx edge, Python backends, evidence).
- `phase-2/<topic>` — Phase 2 extensions (backup DNS, TTL cutover, `pf` isolation, HA failover, diagnostics).
- `feat/<short-name>` — new features or scripts.
- `fix/<short-name>` — bug fixes.
- `docs/<short-name>` — documentation, architecture diagrams, viva prep, and reports.
- `archive/previous-work` — preserved snapshot of the initial repository history prior to restructuring.

## Commit Message Convention

This repository follows **Conventional Commits**:

```text
<type>(<optional-scope>): <imperative summary>
```

Allowed types:
- `feat`: new functionality or network service capability
- `fix`: bug fix in scripts, templates, or backend server
- `docs`: documentation, guides, architecture, or reports
- `test`: unit tests, render checks, or verification scripts
- `refactor`: structural cleanup without changing behavior
- `chore`: repo setup, hooks, templates, config updates

Examples:
- `feat(phase1): add unified backend server and render pipeline`
- `feat(phase2): enable pf isolation and standby nginx failover`
- `fix(scripts): quote interface variable in netinfo.sh`
- `docs(team): update Mac 3 and Mac 4 owner assignments`
- `test(backend): verify ETag 304 conditional responses`

Enable the commit-msg validation hook locally:

```bash
git config core.hooksPath .githooks
```

## Pull Request Checklist

1. Branch from `main` using the naming convention above.
2. Never commit TLS private keys (`tls/out/*.key`), `.DS_Store`, or machine-local `build/` files.
3. If you edit `*.tmpl` files or `config.env`, run `./render.sh` and `bash tests/test_render.sh`.
4. If you edit `backend/`, run `python3 -m unittest discover -s tests -v`.
5. Keep `config.env` free of personal secrets; update `docs/architecture.md` if topology or ports change.
