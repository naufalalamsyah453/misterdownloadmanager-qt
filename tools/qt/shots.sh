#!/usr/bin/env bash
# Screenshots of the Qt window on a virtual X server, for a pull request (CLAUDE.md rule 6).
# Needs: xvfb, imagemagick, a built misterdownloadmanager-qt, and `labserver` for slow downloads.
#   tools/qt/shots.sh <out-dir> [light|dark]
set -euo pipefail
out=${1:?out dir}; scheme=${2:-light}
bin=${MDM_QT_BIN:-target/debug/misterdownloadmanager-qt}
lab=${MDM_LABSERVER_BIN:-target/debug/labserver}
mkdir -p "$out"
"$lab" --faults "rate=400K" >/dev/null 2>&1 &
labpid=$!
trap 'kill $labpid 2>/dev/null || true' EXIT
sleep 1
base=http://127.0.0.1:8090/gen
shoot() { # name, extra args...
  local name=$1; shift
  xvfb-run -a -s "-screen 0 1100x720x24" bash -c '
    export QT_QUICK_CONTROLS_STYLE=Basic HOME=$(mktemp -d)
    '"$([ "$scheme" = dark ] && echo 'export QT_QPA_PLATFORMTHEME= QT_STYLE_OVERRIDE=')"'
    "$0" "$@" &
    app=$!
    sleep 5
    import -window root "'"$out"'/'"$name"'-'"$scheme"'.png"
    kill $app' "$bin" "$@"
}
shoot main --add="$base/20M/ubuntu-24.04.iso?seed=1" --add="$base/8M/report.pdf?seed=2" \
  --add="$base/12M/holiday.mp4?seed=3" --add="$base/3M/album.zip?seed=4"
shoot empty
shoot add-url --dialog
