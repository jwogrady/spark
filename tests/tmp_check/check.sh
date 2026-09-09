#!/usr/bin/env bash
set -euo pipefail
re='^(([0-9]{4}-((0[13578]|1[02])-(0[1-9]|[12][0-9]|3[01])|(0[469]|11)-(0[1-9]|[12][0-9]|30)|02-(0[1-9]|1[0-9]|2[0-8]))|([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)-02-29)T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]Z|[0-9a-f]{40}|W/"[A-Za-z0-9._:/-]+"|"[A-Za-z0-9._:/-]+")$'
for f in tests/tmp_check/pos1.json tests/tmp_check/neg1.json tests/tmp_check/neg2.json tests/tmp_check/neg_empty.json; do
  echo "=== $f ==="
  jq -j --arg re "$re" '
    def canonical:
      if type != "string" then "bad:\(. | tojson) is not a string"
      elif test("\n") then "bad:\(. | tojson) contains a newline"
      elif test($re) then "ok"
      else "bad:\(. | tojson) is not a github-api version" end;
    ([.source.version | canonical]
     + (if (.versions | type) != "object"
        then ["bad-versions-type:\(.versions | type)"]
        else [.versions | to_entries[] | (.value | canonical)] end))
    | join("\n")
  ' "$f"
  echo
done
