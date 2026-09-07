# Runtime surface after canonicalization (v0.23 cleanup, #743)

**Rule.** An extraction or removal earns its place only by removing dead code, eliminating duplicate semantics,
creating one canonical primitive with several consumers, lowering change fanout, or making a boundary testable
with less context. Moving duplication into more files is not one of them, so this unit removes duplicate readers
and adds no module.

**The map comes first, and it covers the whole runtime.** `docs/research/v0.23-cleanup/743-responsibilities.tsv`
assigns every one of the 239 functions in the dispatcher and its three modules to exactly one of the issue's
eight responsibilities, with its body length, everything in the runtime that references it, and the verbs among
those. `743-responsibilities-before.tsv` is the same map at `29e4f4e`, the commit this branch left, so the
before-change baseline is a map and not a pair of totals. Both are generated from `tests/structure.sh --raw` run
per file, and `tests/test-runtime-responsibilities.sh` holds both to their trees: a function added, removed or
renamed fails the suite until the map says where it belongs.

The buckets are not disjoint in this code — `governance_validate`, `di_grade` and `release_gate_projection` each
collect, canonicalize, judge and render in one body — so each function is assigned to the half it owns, and that is
stated rather than smoothed over.

| Responsibility | Functions before | after | Body lines before | after | What it owns |
|---|---|---|---|---|---|
| `argument-parsing` | 1 | 1 | 12 | 12 | reads flags and arguments |
| `routing-dispatch` | 10 | 10 | 93 | 93 | resolves a verb and loads what it needs |
| `source-collection` | 86 | 87 | 1,754 | 1,760 | reads a source of truth (git, gh, the filesystem) and returns it unjudged |
| `canonicalization` | 44 | 44 | 630 | 630 | normalizes what was read into this repository's vocabulary |
| `domain-semantics` | 63 | 63 | 6,750 | 6,731 | owns a rule about what the facts mean |
| `evidence-authority` | 19 | 19 | 505 | 505 | decides what the evidence is admissible for |
| `formatting-reporting` | 12 | 13 | 204 | 205 | renders |
| `compatibility-fallback` | 2 | 2 | 7 | 7 | keeps an older shape working |

| File | Functions before | after |
|---|---|---|
| `plugins/spark/bin/spark` | 150 | 152 |
| `plugins/spark/lib/execution.sh` | 61 | 61 |
| `plugins/spark/lib/planning.sh` | 16 | 16 |
| `plugins/spark/lib/repository.sh` | 10 | 10 |

Module count is unchanged at three. The runtime holds 239 functions and 9,943 body lines, against
237 and 9,955 before: +2 functions, -12 body lines.

Function bodies are not the whole runtime — top-level dispatch, globals and comments live outside them — so the
actual line count is reported too:

| File | Lines before | after | delta |
|---|---|---|---|
| `plugins/spark/bin/spark` | 8,938 | 8,958 | +20 |
| `plugins/spark/lib/execution.sh` | 2,182 | 2,180 | -2 |
| `plugins/spark/lib/planning.sh` | 825 | 825 | +0 |
| `plugins/spark/lib/repository.sh` | 221 | 221 | +0 |

**12,166 lines before, 12,184 after (+18)**, against
9,955 and 9,943 body lines. The file grows while the bodies shrink because each new primitive is
documented where it lives, at the top level, outside any body.

**Argument parsing, measured rather than assigned.** The map is exclusive — one responsibility per function — and
that misrepresents parsing, which no function owns: it sits at the head of every verb. Counting the lines of each
body that touch a positional parameter, `shift`, a usage string or a long option gives the responsibility a size
without inventing an owner. It is a line-level heuristic, not a parser:

| File | Parse lines before | after |
|---|---|---|
| `plugins/spark/bin/spark` | 532 | 533 |
| `plugins/spark/lib/execution.sh` | 206 | 204 |
| `plugins/spark/lib/planning.sh` | 62 | 62 |
| `plugins/spark/lib/repository.sh` | 23 | 23 |

200 functions carried parse lines before and 202 do now, in
823
and 822
lines respectively. That is why extracting a shared parser is rejected below: the lines are per-verb strings and
flags, and a shared parser would either normalize what users see or take it all as parameters.

Two buckets hold 150 of 239 functions and
8,491 of 9,943 body lines. That
concentration is the issue's premise, and it is also the trap: for `cmd_doctor`, `cmd_next` and `cmd_labels` the
rules *are* the product, and there is no lower layer to defer them to. Relocating them would move ownership
without reducing it.

**What the graph names as shared.** A function many runtime bodies reference is a canonical primitive by
demonstration, and must not be duplicated back into a module:

| Primitive | Runtime consumers | Responsibility |
|---|---|---|
| `red` | 42 | `formatting-reporting` |
| `yellow` | 32 | `formatting-reporting` |
| `usage` | 28 | `argument-parsing` |
| `git_root` | 27 | `source-collection` |
| `green` | 24 | `formatting-reporting` |
| `resolve_governance` | 17 | `canonicalization` |
| `pref_get` | 10 | `source-collection` |
| `read_flat_json` | 9 | `source-collection` |

## What this unit changed

Three duplicate readers became one each. Each is a fact that was read in two or three places with byte-identical
bodies — #739's rule, applied to what #739 left behind.

- **`intent_liveness`** — `triage_rows` and `rec_rows` each walked the issues a recorded next action names and
  tallied closed/open/unread with an identical `gh api …/issues/<n> --jq .state` loop. One reader now returns the
  tally; each caller keeps its own projection, and both still tell "no `gh` at all" apart from "`gh` could not
  answer", because that distinction lives in the caller where it is rendered.
- **`di_trunk`** — `cmd_resume` carried its own copy of the remote-trunk idiom (`refs/remotes/origin/HEAD`, else
  `origin/master`/`origin/main`). It calls the primitive now. `repo_trunk` stays separate deliberately: it answers
  the *local* trunk name without touching the network, and collapsing the two would make an offline triage depend
  on a remote ref.
- **`json_escape`** — three identical escapers existed as nested functions (`cmd_state` in the dispatcher,
  `cmd_telemetry` and `cmd_budget` in `lib/execution.sh`). One lives in the dispatcher now, where modules already
  reach for shared primitives and where `tests/test-runtime-modules.sh` forbids a module restating one. The map
  shows the result across the module boundary: its runtime consumers are `cmd_budget`, `cmd_state`, `cmd_telemetry`.
  `js` is untouched: it *strips* quotes and backslashes rather than escaping them, and merging them would silently
  change `spark doctor --requirements --json`.

**Change fanout, across surfaces.** Reader bodies are one measure; the surfaces a change to each fact would
have to reach are another. Each row counts the files naming that fact's idiom at each commit, read the same way on
both sides with `git grep -l`, so a zero is a measured zero:

| Fact | Runtime files before | after | Test files before | after | Doc files before | after |
|---|---|---|---|---|---|---|
| the liveness of the issues a recorded intent names | 1 | 1 | 0 | 0 | 0 | 1 |
| the remote trunk ref | 1 | 1 | 0 | 1 | 0 | 2 |
| a JSON string body | 2 | 1 | 1 | 1 | 0 | 0 |

In reader bodies the same three facts go two to one, two to one and three to one. Runtime files fell for a JSON string body, which is the escaper moving out of the module it was copied into. Test and doc files rose for the liveness of the issues a recorded intent names, the remote trunk ref: this unit's own suite asserts the idiom and its map and manifest name it, which is what a measurement of surfaces is supposed to show rather than hide. No shipped documentation needed an edit: the suites that own the affected verbs exercise them by behaviour, not by naming the idiom.

## What was rejected, and why

- **Extracting a `doctor` module** (1,296 lines the graph names as single-verb) — defensible under the issue's
  second clause, but it removes no duplication, and its payoff must be argued in `runtime_peak_source_bytes` and
  `tests/bench.sh` numbers rather than in line counts. It is a separate unit with its own measurement, not a
  rider on this one.
- **Extracting argument parsing** — the parse lines are per-verb: distinct usage text, distinct flags, distinct
  `-h` bodies. A shared parser would either normalize user-visible strings, which #743 forbids, or take them as
  parameters and save nothing.
- **The legacy state keys** — #738 already ruled that removing them needs evidence no consumer has an unmigrated
  file, or a deprecation window, and that evidence is unknowable from this repository.
- **Anything #738 marked do-not-delete** — the `enhancement` alias and `--prune-deprecated` are public CLI
  behaviour; every `cmd_*` and `fp_hot_*` is reached by name from the dispatch table.

## Acceptance, item by item

- **Responsibilities mapped before change** — `743-responsibilities-before.tsv`, the same map at the base commit,
  generated by the same tool and checked by the same suite.
- **Every removal cites its evidence** — each of the three names the byte-identical bodies it replaced.
- **The dispatcher parses, routes, loads and reports rather than owning duplicate semantics** — the duplication
  removed is exactly the read-a-fact-twice kind; where the dispatcher still owns rules, the map says so and the
  manifest says why relocating them would not help.
- **Counts recorded before and after, not as the sole measure** — the tables above, with the consumer counts that
  actually fell.
- **Fanout compared where mechanically practical** — consumer counts per function, on both sides, computed across
  module boundaries.
- **Module count rises only when duplication or change surface falls** — module count is unchanged at three.
- **No public behaviour or authority guarantee changed** — no CLI semantics touched; `js` and `repo_trunk` left
  alone deliberately.
- **No cleanup-only refactor became a rewrite** — three primitives, no restructuring.
- **Focused and full suites green on the exact HEAD** — recorded in the pull request.
