# connect — service recipes

Per-service connect and smoke-test recipes for the [`connect`](../SKILL.md)
skill. Every recipe follows the same shape: **read the credential from 1Password,
export it the way the tool expects, run one verification call that checks status
without printing the secret.**

Replace `Dev` with the project's vault per the per-project key policy.

## The `op://` reference convention

A committed `.env.tmpl` holds references, never values:

```bash
# .env.tmpl  (safe to commit)
GH_TOKEN=op://Dev/GitHub/token
VULTR_API_KEY=op://Dev/Vultr/api_key
LINODE_TOKEN=op://Dev/Linode/token
GOOGLE_APPLICATION_CREDENTIALS=op://Dev/gcp-sa/credential
```

Run anything with secrets injected from the vault:

```bash
op run --env-file=.env.tmpl -- <command>
```

## Ingest (propose, then confirm)

For each captured key, show the developer the command and wait for confirmation
before running it. Example (GitHub token):

```bash
# proposed — run only after the developer confirms
op item create --category="API Credential" --vault="Dev" --title="GitHub" \
  token="<value captured in .env>"
```

Then confirm it reads back (success = a value returned; do not print it):

```bash
op read "op://Dev/GitHub/token" >/dev/null && echo "GitHub token: readable"
```

## GitHub

```bash
export GH_TOKEN="$(op read op://Dev/GitHub/token)"
gh api user --jq '.login'        # smoke test: prints your username, not the token
```

## Google Cloud

Service-account key file (kept out of git; written transiently, used by ADC):

```bash
op read --out-file ./sa.json op://Dev/gcp-sa/credential
export GOOGLE_APPLICATION_CREDENTIALS="./sa.json"
gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
gcloud projects list --limit=1   # smoke test
# shred ./sa.json with `spark shred-env ./sa.json` once verified
```

Interactive alternative for local dev (no key file):

```bash
gcloud auth application-default login
gcloud auth print-access-token >/dev/null && echo "GCP: authenticated"
```

## Vultr

```bash
export VULTR_API_KEY="$(op read op://Dev/Vultr/api_key)"
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $VULTR_API_KEY" \
  https://api.vultr.com/v2/account     # smoke test: expect 200
```

## Linode

```bash
export LINODE_TOKEN="$(op read op://Dev/Linode/token)"
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $LINODE_TOKEN" \
  https://api.linode.com/v4/account    # smoke test: expect 200
```

## CI / non-interactive

Set a 1Password service-account token in the environment; the `op read` / `op run`
calls above work unchanged:

```bash
export OP_SERVICE_ACCOUNT_TOKEN="<service-account-token>"   # from CI secret store
op run --env-file=.env.tmpl -- <command>
```
