# Security

## Current security surface

Spark ships a zero-dependency POSIX-Bash CLI (`bin/spark`), Git and PreToolUse
enforcement hooks, and a 1Password-based secrets workflow (the `connect` skill
plus `spark shred-env`). There is no server, no network service, and no package
published to a registry. The live surface is therefore the local CLI and the
secret-handling path; the rest of the repo is documentation, skills, and agent
definitions.

## What to avoid

- Do not commit secrets, API keys, tokens, or credentials to this repo. The
  `connect` skill keeps only `op://` references in-repo, and `spark shred-env`
  securely deletes any transient plaintext secrets file (e.g. `.env`).
- Do not hard-code URLs, internal hostnames, or internal identifiers in skills
  or templates intended for public use.

## Reporting a vulnerability

If you discover a security issue — in the CLI, the enforcement hooks, or the
secret-handling path — please do not open a public GitHub issue.

Contact the maintainer directly before disclosing. Once a fix is ready,
coordinate on a disclosure timeline.
