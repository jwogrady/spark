#!/usr/bin/env bash
# Static discriminator-PRESENCE guard for the core skill descriptions (#293).
# It asserts that the minimum identity tokens each skill needs survive a trim —
# never whole sentences, so descriptions stay free to improve. A failure names
# the skill and the missing discriminator.
#
# SCOPE (#313): token presence is NOT routing-accuracy evidence — a description
# could keep every keyword yet mislead a selector. The routing-accuracy evidence
# lives in the governed evaluation suite (evaluations/skill-routing/): graded
# before/after runs over a representative prompt fixture, declared for #293 in
# evaluations/evidence-index.tsv. This file is the cheap CI tripwire; the suite
# is the evidence.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
skills="$root/plugins/spark/skills"
pass=0 fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

# check_desc <skill> <discriminator-ere>...
# Each discriminator is a case-insensitive ERE that must appear in the skill's
# description. Alternation encodes acceptable synonyms.
check_desc() {
  local skill="$1"; shift
  local f="$skills/$skill/SKILL.md" desc m
  [ -f "$f" ] || { bad "$skill: SKILL.md not found"; return; }
  desc="$(awk '/^description:/{sub(/^description:[[:space:]]*/,"");print;exit}' "$f")"
  [ -n "$desc" ] || { bad "$skill: empty description"; return; }
  for m in "$@"; do
    if printf '%s' "$desc" | grep -qiE -- "$m"; then :; else
      bad "$skill: missing routing discriminator /$m/"; return
    fi
  done
  ok
}

# Lifecycle spine — each must state its action, its unit/artifact, and the
# neighbours it must not be confused with.
check_desc ideate    'problem'                          'frame|framing'            'plan'                 'codify'
check_desc plan      'issue'                             'milestone'                'ideate'               'codify'
check_desc codify    'implement'                         'issue'                    'branch'               'validate'   'ship'
check_desc validate  'review'                            '\bcode\b'                '\bsecurity\b'          '\baudit\b'
check_desc ship      'commit'                            'pull request|\bPR\b'      'codify'               'validate'
# Repository-setup pair — must be told apart from each other and from the runtime.
check_desc onboard   'repo|repository'                   'first|arm'                'bootstrap'
check_desc bootstrap 'scaffold'                          'runtime|project'          'connect|service|secret' 'ideate|plan'
# Documentation skills — internal-vs-public and contract-vs-prose boundaries.
check_desc knowledge 'internal'                          'adr|doc'                  'docit|public|marketing' 'crew|intake|author|librarian'
check_desc agents-md 'agents\.md'                        'claude\.md'               'docit|knowledge|/init'

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
