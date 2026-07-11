# audit — purge-mode protocol

The contract for removing what is proven dead or false. The goal is not
cosmetic refactoring: leave the repo provably smaller, truer, and safe to
ship. Evidence beats force; force beats nothing.

## Operating rules

1. **No unsupported claims.** Every claim cites a file path, a command with
   its output, or git evidence. Mark each finding Fact or Hypothesis.
2. **Inspect before asserting.** Read the actual repository first.
3. **Every doc change states what code proves it.** Truthful, not flattering.
4. **Risky removals are isolated** — each in its own commit or patch group.
5. **Tests and builds run when available**; if they cannot, say why and give a
   manual validation plan.
6. **Secrets are never printed.** Generated, vendor, and build artifacts are
   identified before any cleanup.
7. **Adapt commands to the repo** — detect the real toolchain first.

## 03 Evidence Gatherer → `.audit-notes/03-evidence.md`

Reads `.audit-notes/00-map.md`, then works the streams the user scoped (all by
default): dead code · documentation truth · branches · dependencies ·
scripts/build config · test drift. Every finding is one row:

`Area | Claim | Evidence (command or path) | Confidence | Action | Risk | Validation`

Confidence levels:

- **High** — proven by code references, successful command output, or git
  evidence.
- **Medium** — likely from static/graph analysis but not runtime-proven.
- **Low** — hypothesis needing human review.

Example row:

`Deps | "lodash unused" | rg "lodash" src/ -> no hits; not in package.json scripts | High | Remove from package.json | Low | Build + test pass after removal`

## Deletion-safety categories

The Synthesis Lead forces every candidate into one:

- **Safe delete** — generated artifacts, merged branches, files proven
  unreachable, docs proven false.
- **Needs review** — old feature code, ambiguous branches, unreferenced
  assets, migrations, fixtures, scripts, public APIs.
- **Do not delete** — default/protected/release branches, active migrations,
  audit/compliance artifacts, owner-less backups, customer data, secrets,
  production config, and anything referenced by deploy/runtime even when
  static analysis misses it.

## Branch-cleanup protocol

- Classify each branch: merged | unmerged | stale | protected/default/release.
- Distinguish local (`git branch -d`/`-D`) from remote
  (`git push origin --delete`) with exact commands per branch.
- Never delete a remote, protected, default, or release branch automatically —
  those always sit behind the approval gate.

## Documentation-truth protocol

- For each doc claim, find the code that proves or disproves it. Fix the doc
  to match reality or delete it; state the proving code either way.
- In a project built with Spark, also flag **residual process framing** in
  product docs — phase/prompt status headers, `/spark:` stage references,
  "later Spark stages" phrasing — caught mechanically with
  `rg -n 'Phase [0-9]|Prompt 0|/spark:|later Spark stage'` across docs and the
  changelog. The build process belongs in Spark, not in the product docs.

## 04 Synthesis Lead → `.audit-notes/04-slate.md`, then the gate

The Lead consolidates the evidence table, categorizes every candidate, and
presents the slate in-session: proposed removals grouped by category, branch
action list (local/remote, merged/unmerged), and a patch plan.

**Human approval gate:** nothing in *needs review*, no remote-branch deletion,
and no risky-code deletion proceeds without explicit user approval. After
approval, apply removals in small isolated commits, validate after each group
(tests/build/`spark doctor` when available), and finish with a truth report:
docs changed, docs deleted, code deleted, branches recommended for deletion,
risks, validation status.
