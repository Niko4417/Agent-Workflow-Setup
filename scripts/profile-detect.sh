#!/usr/bin/env bash
#
# profile-detect.sh — detect the active product profile for the TARGET repo.
#
# Source it to set $KEIKO_PROFILE, or run it to print the profile:
#   . "$(dirname "$0")/profile-detect.sh"      # sets + exports KEIKO_PROFILE
#   bash scripts/profile-detect.sh             # prints the profile name
#
# Detection mirrors the skills' Step 0 (see profiles/README.md), run against the
# current working directory (the target repo root):
#   1. explicit KEIKO_PROFILE env override wins;
#   2. keiko-native  — CONTEXT.md + docs/planning/decision-addendum.md + quality/project.json;
#   3. keiko-web     — docs/design-system/ present;
#   4. else keiko-web — the SAFE default. A gate never auto-selects keiko-native
#      without its markers, so Native behavior is never an accidental default.

keiko_detect_profile() {
  if [ -n "${KEIKO_PROFILE:-}" ]; then
    printf '%s' "$KEIKO_PROFILE"
    return 0
  fi
  if [ -f CONTEXT.md ] && [ -f docs/planning/decision-addendum.md ] && [ -f quality/project.json ]; then
    printf 'keiko-native'
    return 0
  fi
  printf 'keiko-web'
}

KEIKO_PROFILE="$(keiko_detect_profile)"
export KEIKO_PROFILE

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  printf '%s\n' "$KEIKO_PROFILE"
fi
