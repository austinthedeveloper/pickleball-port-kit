#!/bin/sh
# Runs every Godot test suite headless, then the end-to-end input smoke
# (the real main scene driven through the input map). Exits non-zero if
# either fails. Optional argument: a substring filter on suite.test names
# (skips the e2e).
cd "$(dirname "$0")/.." || exit 2
godot --headless --path . --import >/dev/null 2>&1
filter() {
  grep -v -e "ObjectDB instances were leaked" -e "resources still in use" \
          -e "at: cleanup" -e "at: clear" -e "^Godot Engine" "$1"
}
out=$(mktemp)
godot --headless --path . -s res://tests/run_tests.gd -- "$@" >"$out" 2>&1
status=$?
filter "$out"
# A script error inside a passing test still fails the run.
if grep -q "SCRIPT ERROR" "$out"; then
  echo "FAIL: script errors in the test run (see above)"; status=1
fi
if [ -z "$1" ]; then
  echo "\nend-to-end input smoke:"
  godot --headless --path . -s res://tests/e2e_input.gd >"$out" 2>&1
  e2e=$?
  filter "$out"
  if grep -q "SCRIPT ERROR" "$out"; then
    echo "FAIL: script errors in the e2e run"; e2e=1
  fi
  [ $e2e -ne 0 ] && status=$e2e
fi
rm -f "$out"
exit $status
