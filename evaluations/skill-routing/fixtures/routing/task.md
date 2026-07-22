# Skill-routing evaluation — task and method

> **Graded measurement, n = 1, model-judged.** This suite records how the nine
> core skill descriptions route representative natural-language prompts, so a
> description trim (#293, and any future trim) carries before/after routing
> evidence instead of a bare no-regression claim (#313). It is NOT a live
> selection trace: no harness API exposes Claude Code's actual skill-selection
> decision, so a topology's run is a **single-grader judgment** — the grader
> reads the topology's full description set and, per prompt, records which
> skill a selector reading only those descriptions would choose. Cite it as
> what it is: n = 1, model-judged, estimate-class evidence.

## The task

For each prompt in `answer-key.tsv`, choose exactly one skill from the
candidate set by reading only the descriptions. `caught = 1` when the choice
matches the expected skill; the note records the deciding cue — especially
where a trim removed a literal phrase.

## Candidate set

The nine core skills (`ideate plan codify validate ship onboard bootstrap
knowledge agents-md`) **plus the installed companions as distractors**
(`docit`, `audit`, `connect`) — real sessions select among all of them, and
several boundary prompts (R18, R19, R22) exist to prove the cession clauses
route *out* of the core correctly. Companion descriptions are identical in
both topologies (#293 touched only the core nine).

## Topologies

- `pre-trim-descriptions` — the nine core descriptions at commit `07b972f`
  (immediately before PR #308 merged the #293 trims).
- `current-descriptions` — the descriptions on `master` after #293.

## Adopt / no-regression threshold

A description change is regression-free when its topology scores
**correctness ≥ the pre-trim baseline** on this fixture **and no boundary-pair
prompt (R10–R19) flips**. Known ambiguity or reduced redundancy is documented
in the findings/scorecard notes rather than converted into a green claim —
see the current topology's Q3 score.

## Measurement limits (deliberately restated)

Single grader, single run, judged rather than traced, token/latency figures
estimated. This is decision evidence for the Evaluation → Release seam, not a
benchmark. A future harness that exposes real selection traces should replace
the judgment step and keep the fixture.
