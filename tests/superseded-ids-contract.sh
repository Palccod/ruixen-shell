#!/usr/bin/env bash
# Issue #77: lib/build-shell-json.sh's superseded_ids and
# ruixen.pluginpins/BarWidget.qml's excludedIds both answer the same
# underlying question -- "which stock omarchy.* bar widgets does
# Ruixen treat as superseded / intentionally non-pinnable, because
# Ruixen already owns that surface or behavior" -- and both files'
# own comments say they must be kept in sync BY HAND. That is fragile:
# a future one-sided edit to either list would silently desync install
# behavior (what gets carried across on first takeover) from the
# plugin-pins dropdown (what's offered as pinnable) with nothing to
# catch it.
#
# This test extracts both sets straight from source and fails loudly,
# with the actual missing/extra ids, the moment they diverge. Static
# text extraction only, same reasoning every other test in this repo
# already documents (no live Quickshell instance in CI, and this
# specific list also lives inside a plain bash script, not QML).
#
# Deliberately OUT of scope for this contract: excludedIds also carries
# Ruixen-owned structural ids (ruixen.applauncher, ruixen.workspaces,
# ruixen.tray, ...) that have nothing to do with supersededIds at all
# -- see tests/pluginpins-model.sh's own required_exclusions/
# must_not_exclude checks for that half. Only excludedIds' omarchy.*
# subset participates in this comparison; every id in that subset is
# expected to have a matching reason comment already in one of the two
# source files (see build-shell-json.sh's own superseded_ids comment
# for the full "why" per id).
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"
build_shell_json_sh="$repo_dir/lib/build-shell-json.sh"
widget_qml="$repo_dir/bars/widgets/ruixen.pluginpins/BarWidget.qml"

pass=0
fail_count=0
check() {
  local desc="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    printf 'ok   - %s\n' "$desc"
    pass=$((pass + 1))
  else
    printf 'FAIL - %s\n       got:  %s\n       want: %s\n' "$desc" "$got" "$want"
    fail_count=$((fail_count + 1))
  fi
}

# --- Extract superseded_ids from lib/build-shell-json.sh ------------------
# It's a real bash single-quoted JSON string assigned across several
# lines (superseded_ids='[ ... ]'). Pulled out by line range, then the
# bash-quoting wrapper on the first/last line is trimmed down to just
# the [ / ] themselves (no literal quote character appears in either
# sed pattern below, so there is no quote-escaping trap to fall into),
# leaving pure JSON `jq` can parse directly.
superseded_block="$(sed -n "/^superseded_ids='\[/,/^\]'\$/p" "$build_shell_json_sh")"
superseded_json="$(printf '%s\n' "$superseded_block" | sed -e '1s/.*\(\[\)/\1/' -e '$s/\(\]\).*/\1/')"
superseded_sorted="$(printf '%s' "$superseded_json" | jq -c 'sort' 2>/dev/null || echo 'EXTRACTION_FAILED')"

check "superseded_ids in lib/build-shell-json.sh was found and parses as real JSON (extraction sanity check)" \
  "$([[ "$superseded_sorted" != "EXTRACTION_FAILED" ]] && echo yes || echo no)" "yes"

# --- Extract the omarchy.* subset of excludedIds from BarWidget.qml -------
# excludedIds also carries Ruixen-owned structural ids -- filtered down
# to only the "omarchy."-prefixed entries, which is the actual overlap
# this contract cares about (see the file header comment above).
excluded_block="$(grep -A20 'readonly property var excludedIds:' "$widget_qml")"
excluded_omarchy_sorted="$(grep -o '"omarchy\.[a-zA-Z0-9_-]*"' <<<"$excluded_block" | jq -s -c 'sort')"

check "excludedIds' omarchy.* subset was found (extraction sanity check)" \
  "$([[ "$(jq 'length' <<<"$excluded_omarchy_sorted")" -gt 0 ]] && echo yes || echo no)" "yes"

# --- The actual contract: the two sets must be identical -------------------
check "superseded_ids (build-shell-json.sh) and excludedIds' omarchy.* subset (BarWidget.qml) are the exact same set" \
  "$superseded_sorted" "$excluded_omarchy_sorted"

if [[ "$superseded_sorted" != "$excluded_omarchy_sorted" ]]; then
  missing_from_excluded="$(jq -c -n --argjson a "$superseded_sorted" --argjson b "$excluded_omarchy_sorted" '$a - $b')"
  missing_from_superseded="$(jq -c -n --argjson a "$superseded_sorted" --argjson b "$excluded_omarchy_sorted" '$b - $a')"
  printf 'DIFF - in superseded_ids (build-shell-json.sh) but missing from excludedIds (BarWidget.qml): %s\n' "$missing_from_excluded"
  printf 'DIFF - in excludedIds (BarWidget.qml) but missing from superseded_ids (build-shell-json.sh): %s\n' "$missing_from_superseded"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail_count"
[[ "$fail_count" -eq 0 ]]
