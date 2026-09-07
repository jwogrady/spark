# Runtime surface after canonicalization (v0.23 cleanup, #743)

**Rule.** An extraction or removal earns its place only by removing dead code, eliminating duplicate semantics,
creating one canonical primitive with several consumers, lowering change fanout, or making a boundary testable
with less context. Moving duplication into more files is not one of them, so this unit removes duplicate readers
and adds no module.

**The map comes first.** `docs/research/v0.23-cleanup/743-responsibilities.tsv` assigns every one of the
dispatcher's 152 functions to exactly one of the issue's eight responsibilities, with its body length and
the verbs that reference it. `tests/test-runtime-responsibilities.sh` holds the map to the tree: a function added,
removed or renamed fails the suite until the map says where it belongs. The buckets are not disjoint in this code —
`governance_validate`, `di_grade` and `release_gate_projection` each collect, canonicalize, judge and render in one
body — so each is assigned to the half it owns, and that is stated rather than smoothed over.

| Responsibility | Functions | Body lines | What it owns |
|---|---|---|---|
| `argument-parsing` | 1 | 12 | reads flags and arguments |
| `routing-dispatch` | 5 | 79 | resolves a verb and loads what it needs |
| `source-collection` | 51 | 1,179 | reads a source of truth (git, gh, the filesystem) and returns it unjudged |
| `canonicalization` | 29 | 514 | normalizes what was read into this repository's vocabulary |
| `domain-semantics` | 40 | 4,871 | owns a rule about what the facts mean |
| `evidence-authority` | 13 | 449 | decides what the evidence is admissible for |
| `formatting-reporting` | 11 | 193 | renders |
| `compatibility-fallback` | 2 | 7 | keeps an older shape working |

Two buckets hold 91 of 152 functions and
6,050 of 7,304 body lines. That
concentration is the issue's premise, and it is also the trap: for `cmd_doctor`, `cmd_next` and `cmd_labels` the
rules *are* the product, and there is no lower layer to defer them to. Relocating them would move ownership
without reducing it.

**What the reference graph names as shared.** A function several verbs reference is a canonical primitive by
demonstration, and must not be duplicated back into a module:

| Primitive | Verbs referencing it | Responsibility |
|---|---|---|
| `red` | 22 | `formatting-reporting` |
| `yellow` | 19 | `formatting-reporting` |
| `usage` | 18 | `argument-parsing` |
| `read_flat_json` | 17 | `source-collection` |
| `__spark_memo_key` | 16 | `source-collection` |
| `__spark_memo_read` | 16 | `source-collection` |
| `git_root` | 16 | `source-collection` |
| `green` | 15 | `formatting-reporting` |
| `prefs_operator_path` | 15 | `source-collection` |
| `resolve_prefs` | 15 | `canonicalization` |

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
- **`json_escape`** — three identical escapers existed as nested functions (`cmd_state`, `cmd_telemetry`,
  `cmd_budget`). One lives in the dispatcher now, where modules already reach for shared primitives and where
  `tests/test-runtime-modules.sh` forbids a module restating one. `js` is untouched: it *strips* quotes and
  backslashes rather than escaping them, and merging them would silently change `spark doctor --requirements --json`.

## Before and after

| | Functions | Body lines | File lines | `bin/spark` bytes | `lib/execution.sh` bytes |
|---|---|---|---|---|---|
| before (`29e4f4e`) | 150 | 7,314 | 8,938 | 423,236 | 99,562 |
| after | 152 | 7,304 | 8,958 | 424,744 | 99,377 |

Function bodies shrank by 10 lines while the file grew by 20: the duplicated code is gone and what replaced it is documented at the top level, outside any body. Neither number is the measure #743 asks for, and the manifest does not argue from them. What fell is
the number of readers of each fact — two to one, two to one, three to one — and with it the number of places a
change to any of them has to land.

**Change fanout, measured the only way this repository can.** A change to how the runtime reads an issue's state
touched two functions in two verbs' paths before and touches one now; the remote-trunk idiom, two and now one;
JSON escaping, three and now one. No module count changed, so no verb loads more source than before, and
`tests/test-runtime-modules.sh` still asserts the loaded bytes exactly.

## What was rejected, and why

- **Extracting a `doctor` module** (1,296 lines the graph names as single-verb) — defensible under the issue's
  second clause, but it removes no duplication, and its payoff must be argued in `runtime_peak_source_bytes` and
  `tests/bench.sh` numbers rather than in line counts. It is a separate unit with its own measurement, not a
  rider on this one.
- **Extracting argument parsing** — the 240 parse lines are per-verb: distinct usage text, distinct flags,
  distinct `-h` bodies. A shared parser would either normalize user-visible strings, which #743 forbids, or take
  them as parameters and save nothing.
- **The legacy state keys** — #738 already ruled that removing them needs evidence no consumer has an unmigrated
  file, or a deprecation window, and that evidence is unknowable from this repository.
- **Anything #738 marked do-not-delete** — the `enhancement` alias and `--prune-deprecated` are public CLI
  behaviour; every `cmd_*` and `fp_hot_*` is reached by name from the dispatch table.

## Acceptance, item by item

- **Responsibilities mapped before change** — the map above, generated and machine-checked.
- **Every removal cites its evidence** — each of the three names the byte-identical bodies it replaced.
- **The dispatcher parses, routes, loads and reports rather than owning duplicate semantics** — the duplication
  removed is exactly the read-a-fact-twice kind; where the dispatcher still owns rules, the map says so and the
  manifest says why relocating them would not help.
- **Counts recorded before and after, not as the sole measure** — the table above, with the reader counts that
  actually fell.
- **Fanout compared where mechanically practical** — reader counts per fact, above.
- **Module count rises only when duplication or change surface falls** — no module was added.
- **No public behaviour or authority guarantee changed** — no CLI semantics touched; `js` and `repo_trunk` left
  alone deliberately.
- **No cleanup-only refactor became a rewrite** — three primitives, no restructuring.
- **Focused and full suites green on the exact HEAD** — recorded in the pull request.
