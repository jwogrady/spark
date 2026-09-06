# Spark runtime module: planning (#614)
#
# The plan compiler's command surface and the fourteen helpers only it uses. The
# seam was re-derived on the merged tree rather than carried over: the cluster
# holds, and no function here is reached by any other verb.
#
# What this module DEPENDS ON stays canonical in the dispatcher and is never
# restated: the governance family (resolve_governance, governance_validate,
# governance_records and the model resolvers), preferences resolution, and the
# colour and git-root primitives. Governance in particular is shared with ten
# other verbs — a second copy of it living here to make the module
# self-contained would be precisely the duplicate authority decomposition is
# supposed to prevent.
#
# Sourced, never executed. Shipped source, not a generated artifact.

# ---------------------------------------------------------------------------
# The plan compiler's command surface (#472).
#
#   agent/human intent -> structured plan -> validate -> diff -> approve
#                                                      -> apply -> verify
#
# There is exactly ONE compiler. `issue-manifest.sh` owns the manifest's
# STRUCTURE — record shapes, refs, duplicates, cycles — and owns creating,
# updating and wiring with its resumable state and its shared dry-run/live
# analyzer. This surface owns MEANING: it resolves categories and priorities
# against the governance model, compares the artifact to live GitHub state, and
# verifies the result afterwards. Neither restates the other, and nothing here
# re-implements a call the script already makes.
# ---------------------------------------------------------------------------

plan_script() {
  printf '%s' "$SPARK_ROOT/skills/plan/scripts/issue-manifest.sh"
}

# plan_schema_rows <model> <artifact> — MEANING checks the script deliberately
# does not make: the manifest treats labels as an opaque CSV, so an invalid
# category, two categories, or a typo passed validation and reached GitHub.
# Emits "plan <status> <id> <detail>" rows, the same vocabulary as governance.
plan_schema_rows() {
  local model="$1" artifact="$2"
  PLAN_MODEL="$model" awk -F'\t' '
    BEGIN {
      n = split(ENVIRON["PLAN_MODEL"], ml, "\n")
      for (i = 1; i <= n; i++) {
        split(ml[i], f, "\t")
        if (f[1] == "family") { card[f[2]] = f[3]; req[f[2]] = f[4]
                                if (!(f[2] in seen)) { seen[f[2]] = 1; order[++nf] = f[2] } }
        else if (f[1] == "member")    memof[f[3]] = f[2]
        else if (f[1] == "exclusive") excl[f[2]] = f[3]
      }
    }
    /^[[:space:]]*(#|$)/ { next }
    $1 == "issue" || ($1 == "update" && $3 == "labels") {
      key = $2; csv = $4
      # A create carries the WHOLE set; an update carries family-scoped intent
      # (#637), and the families it does not name keep whatever they already
      # hold. Demanding every required family of an update would force the plan
      # to restate — and so claim authority over — families it is not changing,
      # which is the boundary this record type exists to respect.
      isupd = ($1 == "update")
      # Cleared per RECORD: these accumulate per issue, and a leak between
      # records would count labels from a neighbouring record against this one.
      delete cntn; delete cntv; delete hasv
      nl = split(csv, lab, ",")
      for (j = 1; j <= nl; j++) {
        if (lab[j] == "") continue
        if (!(lab[j] in memof)) {
          printf "plan\t!\t%s\tlabel \"%s\" is not declared by any governed family\n", key, lab[j]
          continue
        }
        mfam = memof[lab[j]]
        cntn[mfam]++
        cntv[mfam] = cntv[mfam] (cntv[mfam] == "" ? "" : ", ") lab[j]
        hasv[mfam SUBSEP lab[j]] = 1
      }
      for (fi = 1; fi <= nf; fi++) {
        fm = order[fi]
        # Member identity is the record here too. The plan compiler and the
        # per-issue validator have to agree about what one member is, or the
        # same governed value validates in one and fails in the other.
        c = (fm in cntn) ? cntn[fm] : 0
        v = (fm in cntv) ? cntv[fm] : ""
        if (c == 0 && req[fm] == "required" && !isupd)
          printf "plan\t!\t%s\t%s is required and the plan declares none\n", key, fm
        else if (c > 1 && (card[fm] == "exactly-one" || card[fm] == "at-most-one"))
          printf "plan\t!\t%s\t%s allows %s but the plan sets %d: %s\n", key, fm, card[fm], c, v
        # The exclusive member has to be checked HERE too. Without it a plan
        # declaring `docs-impact:none` alongside another value validated
        # cleanly and was then hard-FAILed as INVALID at validate time — the
        # precise drift between plan and enforcement this surface exists to
        # stop.
        if ((fm in excl) && c > 1) {
          # Whole-name membership, not a token or a prefix — same rule, same
          # reason as the per-issue check.
          if ((fm SUBSEP excl[fm]) in hasv)
            printf "plan\t!\t%s\t%s is exclusive but the plan combines it with another %s value\n", key, excl[fm], fm
        }
      }
      next
    }
  ' "$artifact"
}

# plan_label_scope <model> <artifact-csv> <live-lines> <projection> (#637)
#
# THE producer for family-scoped label ownership. Validate, diff, apply and
# verify all read it; none of them re-derives it, because two answers to "what
# will this plan leave on the issue" is how apply and verify end up describing
# different repositories while both look right.
#
# Spark's authority over labels is granted by FAMILY. A plan that selects a
# category has said nothing about a project-local label the model never claimed,
# and saying nothing is not permission to delete. The released compiler had no
# way to express that: an unmanaged label in the artifact was refused as
# ungoverned, and one left out was erased by a whole-set PATCH — so an issue
# carrying a legitimate `feedback` label had NO safe update path.
#
# The touched families come from the ARTIFACT, never from live state. The
# artifact is the intent; a family it does not name is not this plan's to
# rewrite, however much of it happens to be sitting on the issue.
#
#   families  the governed families the artifact declares
#   replaced  the live labels those families currently hold — exactly what the
#             update removes, and the set `verify` holds the artifact to
#   target    the resulting set: live, minus `replaced`, plus the artifact's
#             labels. Idempotent, so a correct apply verifies clean.
#
# An ungoverned label in the ARTIFACT is not silently absorbed here: it belongs
# to no family, so it touches none, and `plan_schema_rows` still refuses it.
# Unmanaged labels survive because Spark does not reach into their family, not
# because the governance model was widened to adopt them.
plan_label_scope() {
  PLS_MODEL="$1" PLS_CSV="$2" PLS_LIVE="$3" PLS_WANT="$4" awk '
    BEGIN {
      n = split(ENVIRON["PLS_MODEL"], ml, "\n")
      for (i = 1; i <= n; i++) {
        split(ml[i], f, "\t")
        if (f[1] == "member") memof[f[3]] = f[2]
      }
      na = split(ENVIRON["PLS_CSV"], a, ",")
      for (i = 1; i <= na; i++) {
        if (a[i] == "") continue
        art[a[i]] = 1
        if (!(a[i] in memof)) continue
        # Declaration order, not awk hash order: a set printed in a different
        # order on every run is unreadable in a diff and untestable.
        if (!(memof[a[i]] in touched)) { touched[memof[a[i]]] = 1; forder[++nt] = memof[a[i]] }
      }
      want = ENVIRON["PLS_WANT"]
      if (want == "families") { for (i = 1; i <= nt; i++) print forder[i]; exit }
      nl = split(ENVIRON["PLS_LIVE"], ll, "\n")
      for (i = 1; i <= nl; i++) {
        l = ll[i]
        if (l == "") continue
        owned = (l in memof) && (memof[l] in touched)
        if (want == "replaced") { if (owned) print l }
        # `preserved` is `target` without the plan: what survives untouched.
        else if (!owned && !(l in art)) print l
      }
      if (want == "target") for (i = 1; i <= na; i++) if (a[i] != "") print a[i]
    }
  ' </dev/null
}

# Label SET comparison, for both verification paths.
#
# Both used to compare `[.labels[].name] | sort | join(",")` against a joined
# artifact list. That collapses two distinct GitHub states — the two labels `a`
# and `b`, and the single label named `a,b` — into the same string `a,b`, so
# `verify` could report that labels match the artifact when GitHub did not match
# it. The comparison was symmetric, which is why it looked right.
#
# A set is compared as a set: one name per line, sorted, never joined. These
# live in one place because two implementations of "do these labels match" is
# how the two paths would drift apart while both looking correct.

# artifact_labels <csv> — the artifact grammar's label list, one per line. The
# grammar is unchanged: a comma separates labels in the ARTIFACT, which is a
# file a human writes. What changed is that a name read back from GitHub is
# never re-encoded into that grammar to be compared.
artifact_labels() {
  printf '%s' "$1" | tr ',' '\n' | awk 'NF'
}

# label_set_equal <lines-a> <lines-b> — set equality, order-insensitive.
label_set_equal() {
  [ "$(printf '%s\n' "$1" | awk 'NF' | LC_ALL=C sort)" \
    = "$(printf '%s\n' "$2" | awk 'NF' | LC_ALL=C sort)" ]
}

# label_set_show <lines> — a readable rendering for a message. Never fed back
# into a comparison; that round trip is the defect.
label_set_show() {
  printf '%s\n' "$1" | awk 'NF { printf "%s%s", (n++ ? ", " : ""), $0 }'
}

# plan_ref_num <ref> <state> — the issue NUMBER a manifest ref denotes: a
# literal #N, or the number a KEY became, which only the state file records.
# Empty when unknowable, and callers must report that rather than skip it.
plan_ref_num() {
  case "$1" in
    '#'*) printf '%s' "${1#'#'}" ;;
    *)    [ -f "$2" ] && awk -F'\t' -v k="$1" \
            '$1 == "created" && $2 == k { print $3; exit }' "$2" ;;
  esac
}

# plan_ms_title <value> <artifact> — a milestone field may name a KEY the
# artifact defines; GitHub only ever holds the TITLE. Resolve, else pass through.
plan_ms_title() {
  local t
  t="$(awk -F'\t' -v k="$1" '/^[[:space:]]*(#|$)/ { next }
        $1 == "milestone" && $2 == k { print $3; exit }' "$2")"
  printf '%s' "${t:-$1}"
}

# plan_body_matches <file> <live-body> — 0 iff the issue body is the file.
#
# Compared after normalising line endings and trailing blank lines, because
# GitHub returns CRLF for bodies submitted with LF and drops or adds a trailing
# newline depending on the client. Without that, every correct body reported
# drift, which is worse than not checking: a check that always fails gets
# switched off.
plan_body_matches() {
  local want got
  want="$(tr -d '\r' < "$1" | awk '{ print }' | sed -e :a -e '/^$/{$d;N;};/\n$/ba')"
  got="$(printf '%s' "$2" | tr -d '\r' | sed -e :a -e '/^$/{$d;N;};/\n$/ba')"
  [ "$want" = "$got" ]
}

# plan_relation_rows <artifact> <state> — the mutation-bearing facts that are
# NOT fields on an issue: milestone existence, hierarchy, hard dependencies, and
# preferred order.
#
# `verify` used to read title and labels only. A slate could therefore declare a
# milestone, a parent/child hierarchy, a blocked-by edge and an explicit delivery
# order, have every one of them absent from GitHub, and still be certified as
# matching the artifact — because nothing looked (#517).
# plan_sub_issues <parent> — the parent's sub-issue numbers in GitHub's own
# order, paginated so a large family is never read as its first page, and
# buffered so a failure on a later page never leaves a partial list on stdout.
# The one reader for both the hierarchy and the order check below; fails
# (non-zero, no rows) when the list could not be read, and the caller reports
# `?`, never "not wired".
plan_sub_issues() {
  local rows
  rows="$(gh api --paginate "repos/{owner}/{repo}/issues/$1/sub_issues" --jq '.[].number' 2>/dev/null)" || return 1
  [ -z "$rows" ] || printf '%s\n' "$rows"
}

plan_relation_rows() {
  local artifact="$1" state="$2"
  local key title desc a b c live num pnum cnum found kids reason hit

  # --- milestone records ---------------------------------------------------
  local ms_live ms_ok=1
  if ! ms_live="$(gh api "repos/{owner}/{repo}/milestones?state=all&per_page=100" --paginate \
                    --jq '.[] | "\(.title)\t\(.description // "")"' 2>/dev/null)"; then
    ms_ok=0
  fi
  awk -F'\t' '/^[[:space:]]*(#|$)/ { next } $1 == "milestone" { print $2 "\t" $3 "\t" $4 }' "$artifact" \
  | while IFS=$'\t' read -r key title desc; do
      [ -n "$key" ] || continue
      if [ "$ms_ok" -eq 0 ]; then
        printf 'milestone\t?\t%s\tthe milestone list could not be read — never assumed to exist\n' "$key"
        continue
      fi
      live="$(printf '%s\n' "$ms_live" | awk -F'\t' -v t="$title" '$1 == t { print "found\t" $2; exit }')"
      if [ -z "$live" ]; then
        printf 'milestone\t~\t%s\tno milestone titled "%s" exists\n' "$key" "$title"
      elif [ -n "$desc" ] && [ "${live#found	}" != "$desc" ]; then
        printf 'milestone\t~\t%s\tdescription is "%s"; the artifact says "%s"\n' \
          "$key" "${live#found	}" "$desc"
      else
        printf 'milestone\t=\t%s\texists with the title the artifact asked for\n' "$key"
      fi
    done

  # --- hierarchy -----------------------------------------------------------
  awk -F'\t' '/^[[:space:]]*(#|$)/ { next } $1 == "subissue" { print $2 "\t" $3 }' "$artifact" \
  | while IFS=$'\t' read -r a b; do
      [ -n "$a" ] && [ -n "$b" ] || continue
      pnum="$(plan_ref_num "$a" "$state")"; cnum="$(plan_ref_num "$b" "$state")"
      if [ -z "$pnum" ] || [ -z "$cnum" ]; then
        printf 'hierarchy\t?\t%s/%s\tone side is not a known issue number, so the link cannot be checked\n' "$a" "$b"
        continue
      fi
      if ! kids="$(plan_sub_issues "$pnum")"; then
        printf 'hierarchy\t?\t#%s\tsub-issues could not be read — never assumed wired\n' "$pnum"
        continue
      fi
      if printf '%s\n' "$kids" | grep -Fxq "$cnum"; then
        printf 'hierarchy\t=\t#%s\t#%s is a sub-issue of it, as the artifact asks\n' "$pnum" "$cnum"
      else
        printf 'hierarchy\t~\t#%s\t#%s is NOT a sub-issue of it\n' "$pnum" "$cnum"
      fi
    done

  # --- hard dependencies ---------------------------------------------------
  # The artifact declares an edge between two LOCAL issues, so a blocker counts
  # only when its number AND its repository are the declared one's: a foreign
  # #5 is not the local #5, whatever its state. Own identity is read once; if it
  # cannot be, or a blocker's repository is unknown, the edge is `?`, never `=`.
  local me=""
  me="$(di_repo_nwo)" || me=""
  awk -F'\t' '/^[[:space:]]*(#|$)/ { next } $1 == "blockedby" { print $2 "\t" $3 }' "$artifact" \
  | while IFS=$'\t' read -r a b; do
      [ -n "$a" ] && [ -n "$b" ] || continue
      num="$(plan_ref_num "$a" "$state")"; cnum="$(plan_ref_num "$b" "$state")"
      if [ -z "$num" ] || [ -z "$cnum" ]; then
        printf 'dependency\t?\t%s/%s\tone side is not a known issue number, so the edge cannot be checked\n' "$a" "$b"
        continue
      fi
      if [ -z "$me" ]; then
        printf 'dependency\t?\t#%s\tthe repository identity could not be read, so no blocker can be matched to it\n' "$num"
        continue
      fi
      if ! found="$(gh_blocked_by "$num")"; then
        printf 'dependency\t?\t#%s\tblocked-by could not be read — never assumed wired\n' "$num"
        continue
      fi
      hit="$(printf '%s\n' "$found" | awk -F'\t' -v n="$cnum" -v me="$me" \
        'NF && $1 == n { print ($3 == me ? "same" : ($3 == "" ? "unknown" : "foreign")) }' | LC_ALL=C sort -u | paste -sd, -)"
      case ",$hit," in
        *,same,*)    printf 'dependency\t=\t#%s\tis blocked by #%s, as the artifact asks\n' "$num" "$cnum" ;;
        *,unknown,*) printf 'dependency\t?\t#%s\ta blocker numbered %s exists but its repository could not be determined — never assumed local\n' "$num" "$cnum" ;;
        *)           printf 'dependency\t~\t#%s\tis NOT blocked by #%s\n' "$num" "$cnum" ;;
      esac
    done

  # --- preferred order ----------------------------------------------------
  # Order is applied as RELATIVE placement: the declared children are placed one
  # after another under the parent. So the check is that their relative order in
  # the live sub-issue list matches ascending declared positions — not that each
  # sits at an absolute index, since a parent may hold sub-issues the artifact
  # never mentions.
  local parents
  parents="$(awk -F'\t' '/^[[:space:]]*(#|$)/ { next }
      $1 == "order" { pos[$2] = $3 }
      $1 == "subissue" { par[$3] = $2 }
      END { for (r in pos) if (r in par) print par[r] }' "$artifact" | LC_ALL=C sort -u)"
  printf '%s\n' "$parents" | while IFS= read -r a; do
    [ -n "$a" ] || continue
    pnum="$(plan_ref_num "$a" "$state")"
    if [ -z "$pnum" ]; then
      printf 'order\t?\t%s\tthe parent is not a known issue number, so order cannot be checked\n' "$a"
      continue
    fi
    if ! kids="$(plan_sub_issues "$pnum")"; then
      printf 'order\t?\t#%s\tsub-issue order could not be read — never assumed correct\n' "$pnum"
      continue
    fi
    # The children this parent orders, in declared-position order.
    local want_nums="" r pos_list
    pos_list="$(awk -F'\t' -v p="$a" '/^[[:space:]]*(#|$)/ { next }
        $1 == "order" { pos[$2] = $3 }
        $1 == "subissue" && $2 == p { child[$3] = 1 }
        END { for (r in child) if (r in pos) print pos[r] "\t" r }' "$artifact" \
      | LC_ALL=C sort -n -k1,1 | cut -f2)"
    local missing=0
    for r in $pos_list; do
      cnum="$(plan_ref_num "$r" "$state")"
      if [ -z "$cnum" ]; then missing=1; break; fi
      want_nums="${want_nums}${cnum}"$'\n'
    done
    if [ "$missing" -eq 1 ]; then
      printf 'order\t?\t#%s\tan ordered child is not a known issue number\n' "$pnum"
      continue
    fi
    # Live order, restricted to the ordered children.
    local live_seq
    live_seq="$(printf '%s\n' "$kids" | awk 'NF' \
      | grep -Fx -f <(printf '%s' "$want_nums" | awk 'NF') 2>/dev/null || true)"
    if [ "$(printf '%s' "$live_seq" | awk 'NF' | wc -l | tr -d ' ')" \
         != "$(printf '%s' "$want_nums" | awk 'NF' | wc -l | tr -d ' ')" ]; then
      printf 'order\t~\t#%s\tnot every ordered child is a sub-issue of it\n' "$pnum"
    elif [ "$(printf '%s' "$live_seq" | awk 'NF')" = "$(printf '%s' "$want_nums" | awk 'NF')" ]; then
      printf 'order\t=\t#%s\tits sub-issues are in the order the artifact declares\n' "$pnum"
    else
      printf 'order\t~\t#%s\tsub-issue order is %s; the artifact declares %s\n' "$pnum" \
        "$(printf '%s' "$live_seq" | awk 'NF' | paste -sd, -)" \
        "$(printf '%s' "$want_nums" | awk 'NF' | paste -sd, -)"
    fi
  done
}

# plan_live_rows <artifact> — compare what the artifact says about EXISTING
# issues to what GitHub holds. --dry-run only ever planned calls; it could not
# say `=` correct or `~` drifted, so an update that was already applied looked
# identical to one that had never run.
plan_live_rows() {
  local artifact="$1" n field want live wantcsv model=""
  # Labels are compared family-scoped (#637), which needs the model that says
  # which families exist. If it cannot be resolved the label rows are NOT
  # ASSESSED — never compared as whole sets, because that is the comparison
  # that reported a correctly preserved label as drift.
  model="$(resolve_governance 2>/dev/null)" || model=""
  # A milestone value may be a KEY the artifact defines, and GitHub only ever
  # holds the TITLE — so comparing the raw value reported permanent phantom
  # drift and failed verify after a perfectly correct apply.
  local mstitles
  mstitles="$(awk -F'\t' '/^[[:space:]]*(#|$)/ { next } $1 == "milestone" { print $2 "\t" $3 }' "$artifact")"
  # Same reason as plan_created_rows: tab is IFS-whitespace and collapses, so an
  # empty field would shift every later one left.
  awk -F'\t' -v US=$'\037' '/^[[:space:]]*(#|$)/ { next }
    $1 == "update" { print $2 US $3 US $4 }' "$artifact" \
  | while IFS=$'\037' read -r n field want; do
      [ -n "$n" ] || continue
      case "$n" in '#'*) ;; *) continue ;; esac
      if [ "$field" = "milestone" ]; then
        local resolved
        resolved="$(printf '%s\n' "$mstitles" | awk -F'\t' -v k="$want" 'NF == 2 && $1 == k { print $2; exit }')"
        [ -n "$resolved" ] && want="$resolved"
      fi
      case "$field" in
        title)     live="$(gh issue view "${n#'#'}" --json title --jq .title 2>/dev/null)" || live="__unreadable__" ;;
        milestone) live="$(gh issue view "${n#'#'}" --json milestone --jq '.milestone.title // ""' 2>/dev/null)" || live="__unreadable__" ;;
        labels)    live="$(gh issue view "${n#'#'}" --json labels \
                     --jq '.labels[].name' 2>/dev/null)" || live="__unreadable__"
                   wantcsv="$want"
                   want="$(artifact_labels "$want")" ;;
        body-file)
          # Skipped before, so an applied body update was indistinguishable
          # from one that never ran — and `verify` said PASS either way.
          local bp="$want"
          case "$bp" in /*) ;; *) bp="$(dirname "$artifact")/$bp" ;; esac
          if [ ! -f "$bp" ]; then
            printf 'live\t?\t%s\tbody file %s is missing, so the body cannot be compared\n' "$n" "$want"
            continue
          fi
          if ! live="$(gh issue view "${n#'#'}" --json body --jq .body 2>/dev/null)"; then
            printf 'live\t?\t%s\tbody could not be read — never assumed to match\n' "$n"
            continue
          fi
          if plan_body_matches "$bp" "$live"; then
            printf 'live\t=\t%s\tbody already matches %s\n' "$n" "$want"
          else
            printf 'live\t~\t%s\tbody does not match %s\n' "$n" "$want"
          fi
          continue ;;
        *)         continue ;;
      esac
      if [ "$live" = "__unreadable__" ]; then
        printf 'live\t?\t%s\t%s could not be read — never assumed to match\n' "$n" "$field"
      elif [ "$field" = "labels" ]; then
        # A SET, compared as one. Title and milestone are single scalar facts
        # and compare as strings; labels are not, and joining them to pretend
        # otherwise is what let two labels `a` and `b` match one label `a,b`.
        #
        # And the set compared is the GOVERNED projection, not the whole label
        # list (#637): the question is whether the families this plan declares
        # hold what it says, not whether the issue carries labels the plan never
        # claimed. Comparing the whole set made a preserved `feedback` look like
        # permanent drift and failed `verify` after a perfectly correct apply.
        if [ -z "$model" ]; then
          printf 'live\t?\t%s\tlabels could not be assessed: the governance model would not resolve, so which families this plan owns is unknown\n' "$n"
          continue
        fi
        #
        # The predicate is the producer's own output: the issue matches the plan
        # when it ALREADY holds what applying would leave. Apply writes
        # `target`; verify asserts live equals `target`. One calculation, so the
        # two cannot describe different repositories.
        local replaced preserved suffix
        replaced="$(plan_label_scope "$model" "$wantcsv" "$live" replaced)"
        preserved="$(plan_label_scope "$model" "$wantcsv" "$live" preserved)"
        suffix=""
        [ -n "$preserved" ] && suffix=" (preserved, outside the families this plan owns: $(label_set_show "$preserved"))"
        if label_set_equal "$(plan_label_scope "$model" "$wantcsv" "$live" target)" "$live"; then
          printf 'live\t=\t%s\tlabels already match the plan%s\n' "$n" "$suffix"
        else
          printf 'live\t~\t%s\tgoverned labels are "%s"; the plan says "%s"%s\n' \
            "$n" "$(label_set_show "$replaced")" "$(label_set_show "$want")" "$suffix"
        fi
      elif [ "$live" = "$want" ]; then
        printf 'live\t=\t%s\t%s already matches the plan\n' "$n" "$field"
      else
        printf 'live\t~\t%s\t%s is "%s"; the plan says "%s"\n' "$n" "$field" "$live" "$want"
      fi
    done
}

# plan_created_rows <artifact> <state> — check what a run CREATED against what
# the artifact asked for. The state file is the only record of which KEY became
# which issue number, so verification of a creation is impossible without it —
# and saying that plainly is the point: `verify` used to inspect `update`
# records alone, so a slate of creates and wiring produced no rows and reported
# PASS about a repository it had checked nothing in.
plan_created_rows() {
  local artifact="$1" state="$2" key title labels ms num live want
  if [ ! -f "$state" ]; then
    awk -F'\t' '/^[[:space:]]*(#|$)/ { next } $1 == "issue" { c++ }
      END { if (c) printf "created\t?\tall\t%d created issue(s) cannot be verified: no state file records which number each KEY became\n", c }' \
      "$artifact"
    return 0
  fi
  local body bp mswant
  # Fields are separated by \037, NOT by tab, and read with IFS=$'\037'.
  #
  # Tab is an IFS *whitespace* character, so `IFS=$'\t' read` collapses runs of
  # tabs and strips them at the ends. An issue record that legitimately omits its
  # milestone — `A<TAB>One<TAB>labels<TAB><TAB>body.md` — therefore lost the empty
  # field, `body.md` was read as the milestone, and verification reported
  # `milestone is "(none)"; the artifact says "body.md"` while never comparing the
  # body at all (#540). A unit separator is not IFS-whitespace and preserves
  # empty fields exactly.
  awk -F'\t' -v US=$'\037' '/^[[:space:]]*(#|$)/ { next }
    $1 == "issue" { print $2 US $3 US $4 US $5 US $6 }' "$artifact" \
  | while IFS=$'\037' read -r key title labels ms body; do
      [ -n "$key" ] || continue
      num="$(awk -F'\t' -v k="$key" '$1 == "created" && $2 == k { print $3; exit }' "$state")"
      if [ -z "$num" ]; then
        printf 'created\t?\t%s\tnot recorded as created, so nothing to verify\n' "$key"
        continue
      fi
      # One read for the three scalar facts, so they cannot be mutually
      # inconsistent and the call count does not grow with the checks. The body
      # is a second read only when the artifact declares one.
      # STILL ONE READ, so the three facts cannot be mutually inconsistent —
      # but the labels are their own lines inside it rather than a joined
      # scalar. Title and milestone are single facts and stay scalar; a label
      # set is not one fact, and flattening it is what made `["a","b"]` and
      # `["a,b"]` indistinguishable.
      #
      # A LABEL NAME NEVER PASSES THROUGH @tsv. @tsv is not transparent: it
      # escapes backslash, tab, CR and LF, so a label named `foo\bar` arrived as
      # `foo\\bar` and compared unequal to the artifact's own `foo\bar` — while
      # the live path, which reads the name raw, compared it equal. One legal
      # value, two verification paths, two answers. Structural transport means
      # the bytes survive, not merely that the records are separate.
      #
      # The metadata record stays TSV-encoded, so it is the first line; every
      # later line is one label name, exactly as GitHub spells it.
      live="$(gh issue view "$num" --json title,labels,milestone \
        --jq '([ "meta", .title, (.milestone.title // "") ] | @tsv),
              (.labels[]?.name)' 2>/dev/null)" || {
        printf 'created\t?\t#%s\t%s could not be read — never assumed to match\n' "$num" "$key"
        continue; }
      local l_title="" l_labels="" l_ms="" lfirst=1 lline lmk
      while IFS= read -r lline; do
        if [ "$lfirst" -eq 1 ]; then
          lfirst=0
          IFS=$'\t' read -r lmk l_title l_ms <<EOF_META
$lline
EOF_META
          [ "$lmk" = "meta" ] || { l_title=""; l_ms=""; }
        else
          [ -n "$lline" ] && l_labels="${l_labels}${lline}
"
        fi
      done <<EOF_LIVE
$live
EOF_LIVE
      if [ "$l_title" = "$title" ]; then
        printf 'created\t=\t#%s\t%s exists with the title the artifact asked for\n' "$num" "$title"
      else
        printf 'created\t~\t#%s\ttitle is "%s"; the artifact says "%s"\n' "$num" "$l_title" "$title"
      fi
      if [ -n "$labels" ]; then
        want="$(artifact_labels "$labels")"
        if label_set_equal "$l_labels" "$want"; then
          printf 'created\t=\t#%s\tlabels match the artifact\n' "$num"
        else
          printf 'created\t~\t#%s\tlabels are "%s"; the artifact says "%s"\n' \
            "$num" "$(label_set_show "$l_labels")" "$(label_set_show "$want")"
        fi
      fi
      # The milestone field was READ and then discarded. An issue created into
      # the wrong milestone — or into none — verified clean.
      if [ -n "$ms" ]; then
        mswant="$(plan_ms_title "$ms" "$artifact")"
        if [ "$l_ms" = "$mswant" ]; then
          printf 'created\t=\t#%s\tis in milestone "%s", as the artifact asks\n' "$num" "$mswant"
        else
          printf 'created\t~\t#%s\tmilestone is "%s"; the artifact says "%s"\n' \
            "$num" "${l_ms:-(none)}" "$mswant"
        fi
      fi
      if [ -n "$body" ]; then
        bp="$body"; case "$bp" in /*) ;; *) bp="$(dirname "$artifact")/$bp" ;; esac
        if [ ! -f "$bp" ]; then
          printf 'created\t?\t#%s\tbody file %s is missing, so the body cannot be compared\n' "$num" "$body"
        elif ! l_title="$(gh issue view "$num" --json body --jq .body 2>/dev/null)"; then
          printf 'created\t?\t#%s\tbody could not be read — never assumed to match\n' "$num"
        elif plan_body_matches "$bp" "$l_title"; then
          printf 'created\t=\t#%s\tbody matches %s\n' "$num" "$body"
        else
          printf 'created\t~\t#%s\tbody does not match %s\n' "$num" "$body"
        fi
      fi
    done
}

# spark plan validate|diff|apply|verify <artifact>
# plan_resolve_labels <artifact> <model> <out> — the label set each
# `update ... labels` record should LEAVE on its issue, one "#N<TAB>csv" line
# per record, written to <out> (#637).
#
# Computed once, here, by the surface that owns meaning, and handed to the
# script as the set to write. The script's PATCH stays a whole-set replacement —
# that is the only unambiguous reading of "set the labels to this" — so the set
# it is given must already BE the intended result.
#
# Live state is required, not optional. Without it there is no way to know what
# the plan preserves, and the only remaining move is to write the artifact's
# labels as the whole set: precisely the destructive behaviour this exists to
# remove. An issue whose labels cannot be read is a hard failure before any
# write, never a silent fallback.
plan_resolve_labels() {
  local artifact="$1" model="$2" out="$3" n csv live rc=0
  : > "$out"
  while IFS=$'\037' read -r n csv; do
    [ -n "$n" ] || continue
    case "$n" in '#'*) ;; *) continue ;; esac
    if ! live="$(gh issue view "${n#'#'}" --json labels --jq '.labels[].name' 2>/dev/null)"; then
      red "$n: its live labels could not be read, so what this plan preserves is unknown"
      rc=1; continue
    fi
    printf '%s\t%s\n' "$n" \
      "$(plan_label_scope "$model" "$csv" "$live" target \
         | awk 'NF { printf "%s%s", (i++ ? "," : ""), $0 }')" >> "$out"
  done < <(awk -F'\t' -v US=$'\037' '/^[[:space:]]*(#|$)/ { next }
    $1 == "update" && $3 == "labels" { print $2 US $4 }' "$artifact")
  return "$rc"
}

# plan_has_label_updates <artifact> — 0 iff the artifact updates any labels.
plan_has_label_updates() {
  awk -F'\t' '/^[[:space:]]*(#|$)/ { next }
    $1 == "update" && $3 == "labels" { found = 1 }
    END { exit !found }' "$1"
}

cmd_plan() {
  local usage_line="usage: spark plan validate|diff|apply|verify <artifact> [--tsv] [--yes] [--state FILE]"
  local sub="${1:-}" artifact="" tsv=0 yes=0 state=""
  case "$sub" in
    validate|diff|apply|verify) shift ;;
    -h|--help|'')
      echo "$usage_line"
      echo
      echo "  validate   structure and schema, read-only — nothing is contacted or written"
      echo "  diff       compare the artifact to live GitHub state, read-only"
      echo "  apply      create/update/wire what the artifact specifies (needs --yes)"
      echo "  verify     confirm GitHub matches the artifact after a run"
      return 0 ;;
    *) red "unknown subcommand: $sub"; echo "$usage_line"; return 1 ;;
  esac
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --tsv) tsv=1 ;;
      --yes) yes=1 ;;
      --state)
        if [ "$#" -lt 2 ]; then red "--state needs a file argument"; echo "$usage_line"; return 1; fi
        shift; state="$1" ;;
      -h|--help) echo "$usage_line"; return 0 ;;
      -*) red "unknown option: $1"; echo "$usage_line"; return 1 ;;
      *) if [ -n "$artifact" ]; then red "only one artifact is accepted"; return 1; fi
         artifact="$1" ;;
    esac
    shift
  done
  if [ -z "$artifact" ]; then red "an artifact path is required"; echo "$usage_line"; return 1; fi
  if [ ! -f "$artifact" ]; then red "artifact not found: $artifact"; return 1; fi

  local script model rows structural rc=0
  script="$(plan_script)"
  if [ ! -f "$script" ]; then red "the compiler is missing: $script"; return 1; fi

  case "$sub" in
    validate)
      # Structure first, from the one authority that owns it.
      structural="$(bash "$script" --dry-run "$artifact" 2>&1)" || rc=$?
      if [ "$rc" -ne 0 ]; then
        [ "$tsv" -eq 1 ] || echo "Spark plan — validate"
        printf '%s\n' "$structural" | awk 'NF && /^invalid:/ { print "  ! " substr($0, 10) }'
        printf '%s\n' "$structural" | awk 'NF && !/^invalid:/ && !/^lookup:/ && !/^create:/ && !/^wire:/ && !/^skip:/ && !/^dry-run:/ { print "  " $0 }'
        red "FAIL — the artifact is structurally invalid; nothing would be applied"
        return 1
      fi
      if ! model="$(resolve_governance)"; then
        red "the governance model could not be resolved — see the findings above"
        return 3
      fi
      rows="$(plan_schema_rows "$model" "$artifact")"
      if [ "$tsv" -eq 1 ]; then printf '%s\n' "$rows"; else
        echo "Spark plan — validate"
        echo
        green "  = structure: valid"
        if [ -z "$rows" ]; then green "  = schema: every label resolves, and every cardinality holds"
        else printf '%s\n' "$rows" | awk -F'\t' 'NF { printf "  %s %-14s %s\n", $2, $3, $4 }'
        fi
      fi
      # A plan artifact is an UNAPPROVED draft: correcting it needs no authority
      # over the project's live state, so a schema violation here stays a hard
      # failure rather than becoming DECISION REQUIRED (#559). gov_mechanical_rows
      # is what says so, and it says so in one place.
      if [ -n "$(gov_judgment_rows "$rows")" ]; then
        [ "$tsv" -eq 1 ] || red "DECISION REQUIRED — the plan names live state only a human may decide"
        return 5
      fi
      [ -z "$rows" ] || { [ "$tsv" -eq 1 ] || red "FAIL — the plan declares metadata the schema refuses"; return 1; }
      [ "$tsv" -eq 1 ] || green "PASS — read-only: nothing was contacted or written"
      return 0 ;;
    diff)
      # Read-only. The structural plan says what WOULD be called; the live rows
      # say what already matches, so an applied update is distinguishable from
      # one that never ran.
      structural="$(bash "$script" --dry-run ${state:+--state "$state"} "$artifact" 2>&1)" || {
        red "the artifact is structurally invalid — run: spark plan validate $artifact"; return 1; }
      if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
        rows="$(printf 'live\t?\tall\tnot assessed: comparing to live state needs an authenticated gh\n')"
      else
        rows="$(plan_live_rows "$artifact")"
      fi
      if [ "$tsv" -eq 1 ]; then
        printf '%s\n' "$structural" | awk 'NF { print "structural\t" $0 }'
        printf '%s\n' "$rows"
        return 0
      fi
      echo "Spark plan — diff"
      echo
      printf '%s\n' "$structural" | awk 'NF { print "  " $0 }'
      if [ -n "$rows" ]; then
        echo
        echo "  Against live state:"
        printf '%s\n' "$rows" | awk -F'\t' 'NF { printf "    %s %-10s %s\n", $2, $3, $4 }'
      fi
      echo
      echo "Nothing was written. Apply it with: spark plan apply $artifact --yes"
      return 0 ;;
    apply)
      if [ "$yes" -eq 0 ]; then
        echo "Spark plan — apply is a remote mutation and needs explicit approval."
        echo
        echo "Preview it first:  spark plan diff $artifact"
        echo "Then apply it:     spark plan apply $artifact --yes"
        return 1
      fi
      # Meaning is checked before anything is written: the script validates
      # structure itself, but it treats labels as an opaque CSV.
      if ! cmd_plan validate "$artifact" >/dev/null 2>&1; then
        red "the artifact does not validate — run: spark plan validate $artifact"
        return 1
      fi
      # The families this plan owns are resolved against live state BEFORE
      # anything is written, so the script is handed a result rather than an
      # instruction it would have to interpret. Failing here costs nothing;
      # failing halfway through a whole-set PATCH costs a label.
      local labelmap=""
      if plan_has_label_updates "$artifact"; then
        if ! model="$(resolve_governance)"; then
          red "the governance model could not be resolved — which label families this plan owns is unknown"
          return 3
        fi
        labelmap="$(mktemp)"
        if ! plan_resolve_labels "$artifact" "$model" "$labelmap"; then
          rm -f "$labelmap"
          red "FAIL — nothing was applied"
          return 1
        fi
      fi
      bash "$script" ${state:+--state "$state"} ${labelmap:+--labels-resolved "$labelmap"} "$artifact"
      rc=$?
      [ -n "$labelmap" ] && rm -f "$labelmap"
      return "$rc" ;;
    verify)
      # Confirm GitHub holds what the artifact says, rather than trusting the
      # apply report. A run that reported success can still have been followed
      # by someone editing the issue.
      if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
        yellow "NOT ASSESSED — verifying needs an authenticated gh"
        return 3
      fi
      # Both halves: what the artifact says about EXISTING issues, and what a
      # run CREATED. Checking only the former meant a slate of creates plus
      # wiring produced no rows at all and reported PASS.
      local st_path="${state:-./.issue-manifest.state}"
      rows="$(plan_live_rows "$artifact")
$(plan_created_rows "$artifact" "$st_path")
$(plan_relation_rows "$artifact" "$st_path")"
      rows="$(printf '%s\n' "$rows" | awk 'NF')"
      local bad na
      bad="$(printf '%s\n' "$rows" | awk -F'\t' '$2 == "~" && NF { print }')"
      na="$(printf '%s\n' "$rows" | awk -F'\t' '$2 == "?" && NF { print }')"
      # An empty row set is NOT a pass. There is nothing to verify only because
      # nothing could be checked, which is exactly the case that must never
      # read as confirmation.
      if [ -z "$rows" ]; then
        if [ "$tsv" -eq 1 ]; then printf 'verdict\tNOT ASSESSED\n'
        else
          echo "Spark plan — verify"
          echo
          yellow "NOT ASSESSED — the artifact asserts nothing this verb can check,"
          yellow "               so there is no evidence either way."
        fi
        return 3
      fi
      if [ "$tsv" -eq 1 ]; then
        printf '%s\n' "$rows"
        printf 'verdict\t%s\n' \
          "$([ -n "$bad" ] && echo FAIL || { [ -n "$na" ] && echo "NOT ASSESSED" || echo PASS; })"
      else
        echo "Spark plan — verify"
        echo
        printf '%s\n' "$rows" | awk -F'\t' 'NF { printf "  %s %-10s %s\n", $2, $3, $4 }'
        echo
        if [ -n "$bad" ]; then
          red "FAIL — GitHub does not match the artifact"
          [ -z "$na" ] || yellow "     and some state could not be read, so the picture is partial (?)"
        elif [ -n "$na" ]; then
          yellow "NOT ASSESSED — some state could not be read; never assumed to match"
        else
          green "PASS — GitHub matches the artifact"
        fi
      fi
      [ -z "$bad" ] || return 1
      [ -z "$na" ] || return 3
      return 0 ;;
  esac
}
