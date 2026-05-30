# Security & Configuration Reviewer

**Date:** 2026-05-29
**Reviewer:** jwogrady

## Finding

Security posture is strong. No hardcoded secrets, credentials, or sensitive data observed in the codebase. The connect skill explicitly manages secrets via 1Password (capture → ingest → verify → shred → inject), demonstrating a security-aware design.

**Key security strengths:**
1. **No secrets in code:** `.gitignore` excludes `.env` files (transient); `.env.tmpl` is committed (template only, no secrets).
2. **Enforcement hooks:** PreToolUse guard blocks dangerous bash commands; git hooks prevent accidental commits of unsafe state.
3. **1Password integration:** Secrets are vaulted (personal 1Password account), never committed to git.
4. **Secure deletion:** `shred-env.sh` uses `shred -u` (or `gshred -u`) to securely overwrite transient files; verifies deletion.
5. **No external dependencies:** Zero npm/pip/go packages = zero supply-chain risk from this repository.
6. **Clear guardrails:** CLAUDE.md and AGENTS.md explicitly forbid closing issues, modifying shared state, or pushing without authorization.

**Compliance readiness:**
- No PII or PHI in code
- No hardcoded API keys
- Documentation on how to manage secrets (1Password vault, per-service keys)
- Commit hooks prevent AI attribution (not a compliance issue, but a governance strength)
- No telemetry or tracking observed

**Potential weaknesses:**
1. **guard-bash.sh regex fallback:** If the regex doesn't match a dangerous command, the command passes. Low risk (regexes are conservative), but theoretically exploitable.
2. **git hooks are opt-in:** If a user doesn't run `spark install-git-hooks`, git hooks don't protect. No enforcement at plugin-load time.
3. **.github/workflows/:** Not present (no CI). If CI is added in future, ensure secrets are managed securely (use repository secrets, not .env files).
4. **Review skill concurrency:** No locking on `.review-notes/`. If two reviews run concurrently, file collisions are possible (low risk).

## Evidence

- **No hardcoded secrets:**
  - All `.env` references use `.env.tmpl` (template) or `.env.local` (excluded from git)
  - `.gitignore`: excludes `.env`, `.env.local`, `.env.*.local`
  - Searched codebase for common patterns (AWS_KEY, API_KEY, Bearer, password): none found in committed files

- **1Password integration (connect skill):**
  - `skills/connect/SKILL.md`: lifecycle is capture → ingest (propose-confirm) → verify → shred → inject
  - `skills/connect/references/recipes.md`: per-service recipes (GitHub `gh api user`, GCP `gcloud projects list`, etc.)
  - `.env.tmpl` uses `op://Dev/<service>/<field>` references (committed)
  - `scripts/shred-env.sh`: securely deletes `.env` after verify (never saves secrets to disk)
  - `op run --env-file=.env.tmpl` injects at runtime (secrets never committed)

- **Secure deletion:**
  - `scripts/shred-env.sh` lines 32–48:
    - Attempts `shred -u` (GNU Coreutils, overwrite + delete)
    - Falls back to `gshred -u` (macOS, via coreutils)
    - Falls back to overwrite-with-random + `rm` (portable, works anywhere)
    - Verifies file is deleted: `[[ ! -f "$file" ]]`
    - Refuses to touch `*.tmpl` (templates, meant to be committed)

- **Enforcement hooks:**
  - PreToolUse guard (hooks/guard-bash.sh): blocks `git push --force`, `git push --force-with-lease`, `git push (origin|upstream) (master|main)`
  - git hook (scripts/hooks/pre-commit): blocks commits on master/main
  - git hook (scripts/hooks/commit-msg): rejects commits with AI attribution, missing type, overly long subject

- **Dependency analysis:**
  - `bin/spark`: POSIX bash only, no external tools called
  - `scripts/hooks/`: POSIX bash only, optional jq/python3 (degrades gracefully)
  - `skills/*/`: Markdown + YAML only, no code to audit
  - **Zero npm/pip/python packages:** No `package.json`, `pyproject.toml`, `Gemfile`, or `go.mod` in repo
  - Reduces supply-chain attack surface to zero (relative to this repo)

- **Configuration management:**
  - CLAUDE.md: explicit guardrails (no force-push, no AI attribution, ask before destructive changes)
  - AGENTS.md: contract for agents (scope discipline, reversibility-first)
  - GitHub guardrails: explicit (in CLAUDE.md), enforced via hooks
  - No global config file; configuration is per-project (CLAUDE.md + .git/hooks/)

- **Known attack surfaces:**
  - PreToolUse guard regex: conservative patterns (`--force`, `master`, `main`), low false-positive/false-negative risk
  - Shell script injection: All variables are quoted (`"$var"`), no eval, no backtick execution
  - File path traversal: All file operations use relative/absolute paths, no untrusted input in paths

## Scoring

**Dimension:** Secrets management, compliance, and vulnerability mitigation.

**Score:** 8

**Rationale:** Security posture is strong: no secrets in code, 1Password integration, secure deletion, comprehensive enforcement. Deduction from 9 to 8: guard-bash.sh regex fallback is conservative but theoretically exploitable; git hooks are opt-in (not enforced at plugin-load time); no CI present (future risk if misconfigured); review skill has no file locking (concurrent runs could collide).

## Notes to Next Agent

- **Product readiness:** Check if Spark is ready to ship to external users (no breaking issues, clear documentation, install process tested).
- **Performance:** Scripts are fast. No performance concerns.
- **Observability:** guard-bash.sh silently allows/blocks. Consider logging blocked attempts for auditing (optional enhancement).
