# Security

## Current security surface

Spark is currently a documentation and skills repo. There is no runtime,
no server, no API, and no package published to any registry. The attack surface
is effectively zero at this stage.

## What to avoid

- Do not commit secrets, API keys, tokens, or credentials to this repo.
- Do not add `.env` files or credential files, even to `.gitignore`.
- Do not hard-code URLs, internal hostnames, or internal identifiers in skills
  or templates intended for public use.

## Reporting a vulnerability

If a future version of Spark includes runtime tooling and you discover a
security issue, please do not open a public GitHub issue.

Contact the maintainer directly before disclosing. Once a fix is ready,
coordinate on a disclosure timeline.

This policy will be updated when a runtime with a real security surface exists.
