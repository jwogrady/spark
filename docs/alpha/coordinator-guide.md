# Spark Alpha — coordinator guide

> For the person running the Alpha. How participants are identified, how consent
> and evidence are handled, and how raw feedback becomes decisions. The program
> is [alpha-program.md](alpha-program.md); participants file the
> [alpha-feedback issue form](../../.github/ISSUE_TEMPLATE/alpha-feedback.yml).

## Participant identity — pseudonyms only

Assign every participant a pseudonym on intake: `P1`, `P2`, … The **only** place
that maps a pseudonym to a real person is a private coordinator-held list —
never the repository, never an issue, never a commit. Participants are told to
use their pseudonym in the feedback form and to keep their real name/email out
of it. This keeps the public evidence trail usable without exposing anyone.

## Consent for observed or recorded sessions

- Recording or live-observation is **opt-in and explicit**, captured before the
  session, per session. No silent recording.
- Recordings and any notes containing identifying detail live in the private
  store (below), **never** attached to a GitHub issue.
- A participant may **revoke** consent afterward; on revocation, delete the
  recording and keep only de-identified findings already derived from it.
- If a participant declines recording, the written form + a synchronous debrief
  is enough — do not pressure.

## Where evidence lives

| Evidence | Sensitivity | Home |
|---|---|---|
| Structured per-run reports | de-identified, safe to share | `alpha-feedback` issues in this repo |
| Friction-log notes | de-identified | GitHub Discussions / `alpha-feedback` issues |
| The pseudonym→identity map | identifying | private coordinator store, outside the repo |
| Recordings / raw session notes | may identify or expose work | private coordinator store, outside the repo |

The repo holds only what is safe to be public. The issue form's required
privacy check is the first line of defense; if a report slips through with
sensitive content, **edit or delete it immediately** and ask the participant to
refile de-identified.

## Counting independent corroboration

A finding is promoted only on **independent** reproduction, never on volume or
seniority:

- Count **one vote per distinct participant pseudonym**. Three reports from `P3`
  are one voice, not three.
- A voice counts as independent only if it was **not coordinator-prompted** —
  something the participant raised unbidden, not an answer to "did X bother
  you?"
- Threshold: **≥3 independent participants** on the same point makes it a
  must-address finding. A single strong opinion (even an expert's) stays a
  hypothesis until a second independent experience corroborates it.
- Delight is counted the same way: a workflow ≥3 independent participants call
  helpful/magical is a protected **Preserve**.

## Turning feedback into Learn / Improve / Preserve

Triage the `alpha-feedback` issues on a regular cadence (weekly is plenty for a
cohort this size) and route each recurring signal:

- **Preserve** — corroborated by ≥3 independent participants as working/valued,
  or already validated by engineering evidence. Protect it from churn; changing
  it now needs extraordinary evidence.
- **Improve** — a change justified by ≥3-participant corroboration, where the
  right fix is clear and does not reopen a "should this concept exist" question.
  File as a normal lifecycle issue.
- **Learn** — a real signal that isn't yet actionable: too few independent
  voices, or it raises a conceptual/redesign question. Keep gathering targeted
  evidence before acting.

Map the outcomes back onto the [exit criteria](exit-criteria.md): the program
ends when every Learn item has a disposition and the Alpha→Beta thresholds are
met — on evidence, not on a date.

## Distinguishing product friction from environment failure

Before logging a participant's problem as a Spark finding, separate the two:

- **Environment failure** — `gh` not authenticated, wrong Claude Code version,
  missing Git, network/credential issues. `spark doctor --requirements` is the
  arbiter: if it reports *not ready*, the problem is the environment, not the
  product. Fix the setup and re-run; don't score it as workflow friction.
- **Product friction** — the environment is *ready* per `doctor --requirements`
  and the participant still gets confused, blocked, or surprised. This is the
  signal Alpha exists to collect.

When in doubt, reproduce with a clean environment (`e2e-marketplace-install.sh`
is the reference clean-install path). Only friction that survives a ready
environment counts against the product.

## What this program is not

No analytics infrastructure, automated scoring, dashboards, telemetry, or new
product features are part of the Alpha. The evidence is human and qualitative by
design; adding instrumentation would trade the signal we need for numbers we
don't.
