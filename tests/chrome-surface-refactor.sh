#!/usr/bin/env bash
# Contract for the dock/frame chrome refactor bridge: BarPanel still owns
# widget layout, but publishes per-screen dock geometry for FrameWindow to
# consume before any visual chrome is moved across surfaces.
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"
bar_qml="$repo_dir/bars/v2/ruixen.bar/Bar.qml"
run_all="$repo_dir/tests/run-all.sh"

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

check "root stores dock chrome metrics per screen, not as one global scalar" \
  "$(grep -c 'property var dockChromeMetricsByScreen: ({})' "$bar_qml")" "1"

check "root exposes a serial so var-map metric updates notify frame bindings" \
  "$(grep -c 'property int dockChromeMetricsSerial: 0' "$bar_qml")" "1"

check "dock chrome metrics are keyed by the real layer-window screen name" \
  "$(grep -c 'function screenNameForWindow(window)' "$bar_qml")" "1"

check "publishing dock metrics copies the map before replacing one screen entry" \
  "$(( $(grep -A18 'function publishDockChromeMetrics' "$bar_qml" | grep -F -c 'var next = {}') + $(grep -A18 'function publishDockChromeMetrics' "$bar_qml" | grep -F -c 'next[existing] = root.dockChromeMetricsByScreen[existing]') + $(grep -A22 'function publishDockChromeMetrics' "$bar_qml" | grep -F -c 'root.dockChromeMetricsByScreen = next') ))" "3"

check "FrameWindow consumes the same per-screen dock metric channel" \
  "$(( $(grep -A6 'component FrameWindow' "$bar_qml" | grep -c 'dockChromeScreenName: root.screenNameForWindow(frameWindow)') + $(grep -A6 'component FrameWindow' "$bar_qml" | grep -c 'dockChromeSerial: root.dockChromeMetricsSerial') + $(grep -A6 'component FrameWindow' "$bar_qml" | grep -c 'dockChromeMetrics: root.dockChromeMetrics(dockChromeScreenName)') ))" "3"

check "horizontal dock layout publishes measured left and right extents" \
  "$(( $(grep -A16 'id: horizontalBarRoot' "$bar_qml" | grep -c 'leftWidth: settingsPill.x + settingsPill.width') + $(grep -A16 'id: horizontalBarRoot' "$bar_qml" | grep -c 'rightX: rightDockedBg.x') + $(grep -A16 'id: horizontalBarRoot' "$bar_qml" | grep -c 'rightWidth: horizontalBarRoot.width - rightDockedBg.x') ))" "3"

check "dock metric publishing is scoped to top docked mode only for this first refactor slice" \
  "$(grep -A5 'function publishDockChromeMetrics()' "$bar_qml" | grep -c 'if (!root.docked || root.position !== "top") return')" "1"

check "dock metric updates are triggered by both left and right dock geometry changes" \
  "$(( $(grep -A5 'id: leftDockedBg' "$bar_qml" | grep -c 'onWidthChanged: horizontalBarRoot.publishDockChromeMetrics') + $(grep -A8 'id: rightDockedBg' "$bar_qml" | grep -c 'horizontalBarRoot.publishDockChromeMetrics') + $(grep -A20 'id: trayPill' "$bar_qml" | grep -c 'horizontalBarRoot.publishDockChromeMetrics') ))" "5"

# shellcheck disable=SC2016 # deliberately literal: expected run-all entry contains $script_dir.
check "tests/run-all.sh runs this suite" \
  "$(grep -m1 'chrome-surface-refactor.sh' "$run_all")" \
  '  "$script_dir/chrome-surface-refactor.sh"'

printf '\n%d passed, %d failed\n' "$pass" "$fail_count"
[[ "$fail_count" -eq 0 ]]
