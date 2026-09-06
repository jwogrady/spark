# Reviewer attempts and finding text of record (#730 baseline)

`pr727/findings.txt` and `pr724/findings.txt` record **every marked reviewer attempt** on PR #727 (16) and
PR #724 (35: 32 by the reviewer lane's own login `github-actions[bot]`, 3 relayed markers posted by the
repository owner on HEADs `1bb345c`, `02d88c7`, `143bd9c`) in source chronology, and every finding they contain,
copied **byte-for-byte** from the GitHub comment named in each `## r<id>` header (comment id, HEAD, verdict,
`trust=trusted|relayed`, login, kind, time). Round ids `r1…r32` are the trusted verdicts; a relayed attempt is
`r<n>r` after the trusted round of the same HEAD.

Record format: a `### <id>.<n>` line is a **synthetic id envelope**; the lines after it, up to the next
`###`/`##`, are the original block byte-for-byte. `kind=findings` blocks are the top-level list items — hyphen
bullets or ordered `1.` items — of a blocking verdict, each with its continuation lines, indented sub-items and
internal blank lines; `kind=prose` is a blocking verdict with no list items, whose whole reviewer section is the
one finding; `kind=evidence` are the bullets of the PASS comment, recorded but **not** counted as findings.

`findings-validation.txt` beside each file is the output of `tools/validate-findings.py`, which proves the record
in **both directions** against live GitHub: every block (envelope removed, writer's trailing newline removed, body
CRLF→LF, nothing else) is a verbatim substring of its comment and the block count equals what the parser finds in
that body; and every comment on the PR carrying a `spark-openai-review` marker within the observation cutoff —
any login — has a header in the record. `tools/test-findings-parser.py` holds discriminating fixtures for hyphen,
ordered-list, prose/code-only, PASS-evidence and CRLF shapes. The finding-record toolchain lives in this
bundle's `tools/` (`fetch-pr.sh`, `fetch-commits.sh`, `findings_parser.py`, `analyze-pr.py`, `dump-findings.py`,
`validate-findings.py`, `test-findings-parser.py`); the #730 analysis bundle (PR #747) consumes its output
(`derived.compact.json`) and holds the hand classification `raw/findings-classification.tsv`, whose finding ids
are `<id>.<n>`. Measurement evidence only; nothing here changes Spark.
