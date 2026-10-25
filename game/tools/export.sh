#!/bin/sh
# Release exports (playbook 0.1, §9). Writes game/build_id.txt from
# `git describe --tags --always --dirty`, refusing a dirty tree, then exports each
# preset in export_presets.cfg into build/. Without Godot's export
# templates it says so and makes only the platform-free .pck (the export
# check), then boots the .pck headless for 200 frames.
#   game/tools/export.sh            # every preset (needs templates)
#   game/tools/export.sh --check    # the .pck check only
#   game/tools/export.sh --dev      # allow a dirty tree (the ID says -dirty)
# The Web build (port ADR-089) is exported from a copy of the project in
# build/web-src with smaller music and ambience (encode_ogg.py --web, from
# the WAVs in audio/; needs soundfile: .venv, else python3), and its preset
# carries the "lite" feature, whose exclude_filter leaves out the
# announcer, ROAD TRIP and the painted venues. Its pack is booted too.
cd "$(dirname "$0")/.." || exit 2
KIT="$(cd .. && pwd)"
check=0
dev=0
for a in "$@"; do
  [ "$a" = "--check" ] && check=1
  [ "$a" = "--dev" ] && dev=1
done
if ! git -C "$KIT" diff --quiet HEAD -- ; then
  if [ $dev -eq 0 ]; then
    echo "refused: the tree has uncommitted changes (commit, or pass --dev)"; exit 1
  fi
fi
id=$(git -C "$KIT" describe --tags --always --dirty)
printf '%s\n' "$id" > build_id.txt
echo "build $id"
godot --headless --path . --import >/dev/null 2>&1
ver=$(godot --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?)\.([a-z]+).*/\1.\3/')
templates="$HOME/Library/Application Support/Godot/export_templates/$ver"
[ -d "$templates" ] || templates="$HOME/.local/share/godot/export_templates/$ver"
status=0
mkdir -p "$KIT/build/pck"
godot --headless --path . --export-pack "Linux" "$KIT/build/pck/Pickleball94.pck" >/dev/null 2>&1 || status=1
if [ $status -ne 0 ] || [ ! -s "$KIT/build/pck/Pickleball94.pck" ]; then
  echo "FAIL: the .pck export"; exit 1
fi
echo "ok   .pck exported ($(du -h "$KIT/build/pck/Pickleball94.pck" | cut -f1))"
out=$(godot --headless --main-pack "$KIT/build/pck/Pickleball94.pck" --quit-after 200 2>&1)
if echo "$out" | grep -q "SCRIPT ERROR"; then
  echo "$out" | grep "SCRIPT ERROR"; echo "FAIL: the .pck doesn't boot cleanly"; exit 1
fi
echo "ok   the .pck boots and runs 200 frames"
[ $check -eq 1 ] && exit 0
if [ ! -d "$templates" ]; then
  echo "no export templates for $ver: install them (Editor > Manage Export Templates), then re-run"
  exit 3
fi
py="$KIT/.venv/bin/python"
[ -x "$py" ] || py=python3
web_src() {
  src="$KIT/build/web-src"
  mkdir -p "$src"
  rsync -a --delete --exclude=/build_id.txt ./ "$src/" && cp build_id.txt "$src/" || return 1
  "$py" tools/encode_ogg.py --web "$src/assets/audio" \
    "$KIT/audio/music/out/"music_*.wav "$KIT/audio/hd-sfx/out/"ambience_*.wav || return 1
  godot --headless --path "$src" --import >/dev/null 2>&1
}
for p in macOS Windows Linux Web; do
  dest=$(awk -v p="$p" '$0=="name=\""p"\"" {f=1} f && /^export_path=/ {gsub(/export_path=|"/,""); print; exit}' export_presets.cfg)
  mkdir -p "$(dirname "$dest")"
  proj=.
  if [ "$p" = "Web" ]; then
    web_src || { echo "FAIL Web: its smaller audio"; status=1; continue; }
    proj="$KIT/build/web-src"
    dest="$(cd "$(dirname "$dest")" && pwd)/$(basename "$dest")"
  fi
  if godot --headless --path "$proj" --export-release "$p" "$dest" >/dev/null 2>&1 && [ -e "$dest" ]; then
    echo "ok   $p -> build/${dest#*/build/}"
  else
    echo "FAIL $p"; status=1
  fi
done
# the Web build's pack boots on the desktop engine too: it has "lite" on
# and none of what it leaves out is asked for at the title or in a demo
if [ -s "$KIT/build/web/index.pck" ]; then
  out=$(godot --headless --main-pack "$KIT/build/web/index.pck" --quit-after 600 2>&1)
  if echo "$out" | grep -qE "SCRIPT ERROR|ERROR: .*(load|Resource)"; then
    echo "$out" | grep -E "SCRIPT ERROR|ERROR"; echo "FAIL: the Web pack doesn't boot cleanly"; status=1
  else
    echo "ok   the Web pack boots ($(du -h "$KIT/build/web/index.pck" | cut -f1))"
  fi
fi
exit $status
