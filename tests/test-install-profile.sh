#!/usr/bin/env bash
# Installer authority regressions for both profiles. All target and global
# harness writes are isolated in a temporary directory.
# Run: bash tests/test-install-profile.sh

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/scripts/install.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
TEST_HOME="$T/home"
mkdir -p "$TEST_HOME"

pass=0 fail=0
check() { # description condition-cmd...
  if "${@:2}"; then pass=$((pass+1)); echo "ok   - $1"
  else fail=$((fail+1)); echo "FAIL - $1"; fi
}

mk_target() { # dir profile
  local d="$1" profile="$2"
  mkdir -p "$d"
  git -C "$d" init -q
  if [[ "$profile" == "keiko-native" ]]; then
    mkdir -p "$d/docs/planning" "$d/quality"
    touch "$d/CONTEXT.md" "$d/docs/planning/decision-addendum.md" "$d/quality/project.json"
  else
    mkdir -p "$d/docs/design-system"
  fi
}

install_target() {
  env -u KEIKO_PROFILE HOME="$TEST_HOME" bash "$INSTALL" "$1" >"$1/install-output" 2>&1
}

for profile in keiko-web keiko-native; do
  for kind in regular symlink dangling absent; do
    target="$T/$profile-$kind"
    mk_target "$target" "$profile"
    for doc in AGENTS.md CLAUDE.md; do
      case "$kind" in
        regular) printf '%s-own-%s\n' "$profile" "$doc" > "$target/$doc" ;;
        symlink)
          printf '%s-own-%s\n' "$profile" "$doc" > "$target/owned-$doc"
          ln -s "owned-$doc" "$target/$doc"
          ;;
        dangling) ln -s "missing-$doc" "$target/$doc" ;;
      esac
    done
    # Pin one root document in the index; the other remains untracked so the
    # same fixture proves both tracked authority and new-document visibility.
    if [[ "$kind" != "absent" ]]; then
      git -C "$target" add AGENTS.md
    fi
    check "$profile/$kind: install succeeds" install_target "$target"
    check "$profile/$kind: detected profile" grep -qF "profile: $profile" "$target/install-output"
    for harness in .codex .claude .agents .mcp.json .keiko-scripts; do
      check "$profile/$kind: $harness linked" test -L "$target/$harness"
    done
    for doc in AGENTS.md CLAUDE.md; do
      case "$kind" in
        regular)
          check "$profile: $doc remains a regular file" bash -c '[ -f "$1" ] && [ ! -L "$1" ]' _ "$target/$doc"
          check "$profile: $doc content preserved" grep -qxF "$profile-own-$doc" "$target/$doc"
          ;;
        symlink)
          check "$profile: $doc symlink preserved" bash -c '[ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]' _ "$target/$doc" "owned-$doc"
          check "$profile: $doc referent preserved" grep -qxF "$profile-own-$doc" "$target/owned-$doc"
          ;;
        dangling)
          check "$profile: dangling $doc symlink preserved" bash -c '[ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]' _ "$target/$doc" "missing-$doc"
          check "$profile: unavailable $doc reported" grep -qF "WARNING: target authority document unavailable: $doc" "$target/install-output"
          ;;
        absent)
          check "$profile: absent $doc stays absent" bash -c '[ ! -e "$1" ] && [ ! -L "$1" ]' _ "$target/$doc"
          check "$profile: absent $doc reported" grep -qF "WARNING: target authority document unavailable: $doc" "$target/install-output"
          ;;
      esac
      check "$profile/$kind: $doc not backed up" bash -c '[ ! -e "$1" ] && [ ! -L "$1" ]' _ "$target/$doc.bak"
      check "$profile/$kind: $doc not excluded" bash -c '! git -C "$1" check-ignore -q -- "$2"' _ "$target" "$doc"
    done
    if [[ "$kind" != "absent" ]]; then
      check "$profile/$kind: tracked authority unchanged" git -C "$target" diff --exit-code -- AGENTS.md
    fi
    check "$profile/$kind: reinstall succeeds" install_target "$target"
    case "$kind" in
      regular|symlink)
        check "$profile/$kind: authority survives reinstall" grep -qxF "$profile-own-AGENTS.md" "$target/AGENTS.md"
        ;;
      dangling)
        check "$profile/$kind: dangling authority survives reinstall" bash -c '[ "$(readlink "$1")" = "missing-AGENTS.md" ]' _ "$target/AGENTS.md"
        ;;
      absent)
        check "$profile/$kind: absent authority survives reinstall" bash -c '[ ! -e "$1" ] && [ ! -L "$1" ]' _ "$target/AGENTS.md"
        ;;
    esac
  done
done

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
