#!/usr/bin/env bash
# Evaluate every policy declared in policies.hcl against an input document,
# mimicking how Terraform Enterprise reports policy evaluation results.
#
# Usage:
#   scripts/eval-policy-set.sh <input.json> [policy-set-dir]
#
# Env:
#   OPA=/path/to/opa   use a specific OPA binary (match your TFE runtime version)
#
# Exit codes: 0 = no mandatory failures, 1 = mandatory failure(s), 2 = error
set -uo pipefail

INPUT="${1:?usage: $0 <input.json> [policy-set-dir]}"
SET_DIR="${2:-$(cd "$(dirname "$0")/../policy-set" && pwd)}"
OPA="${OPA:-opa}"
HCL="$SET_DIR/policies.hcl"

command -v "$OPA" >/dev/null || { echo "opa not found (set OPA=...)" >&2; exit 2; }
[[ -f "$INPUT" ]] || { echo "input not found: $INPUT" >&2; exit 2; }
[[ -f "$HCL" ]]   || { echo "policies.hcl not found in $SET_DIR" >&2; exit 2; }

echo "OPA:    $("$OPA" version | head -1)"
echo "Set:    $SET_DIR"
echo "Input:  $INPUT"
echo

passed=0; advisory_failed=0; mandatory_failed=0; errored=0

# Emit "name|query|level" for each policy block (level defaults to advisory).
parse_policies() {
  awk '
    /^[[:space:]]*policy[[:space:]]+"/ {
      match($0, /"[^"]+"/); name = substr($0, RSTART + 1, RLENGTH - 2)
      query = ""; level = "advisory"
    }
    /^[[:space:]]*query[[:space:]]*=/ {
      match($0, /"[^"]+"/); query = substr($0, RSTART + 1, RLENGTH - 2)
    }
    /^[[:space:]]*enforcement_level[[:space:]]*=/ {
      match($0, /"[^"]+"/); level = substr($0, RSTART + 1, RLENGTH - 2)
    }
    /^}/ { if (name != "") print name "|" query "|" level; name = "" }
  ' "$HCL"
}

while IFS='|' read -r name query level; do
  # One expression returning "<type>\t<count>\t<msg1>\x1f<msg2>..."; empty if undefined.
  expr="sprintf(\"%s\t%d\t%s\", [type_name(${query}), count(${query}), concat(\"\u001f\", [sprintf(\"%v\", [m]) | m := ${query}[_]])])"
  out=$("$OPA" eval --format raw -d "$SET_DIR" -i "$INPUT" "$expr" 2>&1)
  rc=$?

  if [[ $rc -ne 0 || -z "$out" ]]; then
    printf '%-22s %-10s ERROR\n' "$name" "$level"
    [[ -n "$out" ]] && printf '    %s\n' "$out" || printf '    query %s is undefined\n' "$query"
    errored=$((errored + 1)); continue
  fi

  IFS=$'\t' read -r type count msgs <<<"$out"
  if [[ "$type" != "array" && "$type" != "set" ]]; then
    printf '%-22s %-10s ERROR\n    query must return an array, got %s\n' "$name" "$level" "$type"
    errored=$((errored + 1)); continue
  fi

  if [[ "$count" -eq 0 ]]; then
    printf '%-22s %-10s passed\n' "$name" "$level"
    passed=$((passed + 1))
  else
    printf '%-22s %-10s FAILED (%s)\n' "$name" "$level" "$count"
    IFS=$'\x1f' read -r -a lines <<<"$msgs"
    for l in "${lines[@]}"; do printf '    - %s\n' "$l"; done
    if [[ "$level" == "mandatory" ]]; then
      mandatory_failed=$((mandatory_failed + 1))
    else
      advisory_failed=$((advisory_failed + 1))
    fi
  fi
done < <(parse_policies)

echo
echo "Passed: $passed  Advisory failures: $advisory_failed  Mandatory failures: $mandatory_failed  Errors: $errored"
if (( errored > 0 )); then
  echo "Result: ERRORED (TFE would report the policy evaluation as errored)"; exit 2
elif (( mandatory_failed > 0 )); then
  echo "Result: BLOCKED (apply requires a policy override)"; exit 1
else
  echo "Result: CAN PROCEED"; exit 0
fi
