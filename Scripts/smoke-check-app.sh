#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage:
  Scripts/smoke-check-app.sh <path-to-AwakeBar.app> [expected-team-id]

Examples:
  Scripts/smoke-check-app.sh build/AwakeBar.app
  Scripts/smoke-check-app.sh build/AwakeBar.app 6EC5ZH6Y22
EOF
}

fail() {
  echo "smoke-check failed: $1" >&2
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 64
fi

APP_PATH="$1"
EXPECTED_TEAM_ID="${2:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONSTANTS_FILE="$ROOT/AwakeBarShared/PrivilegedServiceConstants.swift"

[[ -d "$APP_PATH" ]] || fail "app not found at '$APP_PATH'"
[[ -f "$CONSTANTS_FILE" ]] || fail "missing constants file '$CONSTANTS_FILE'"

for tool in awk codesign /usr/libexec/PlistBuddy; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    fail "required tool '$tool' is not available"
  fi
done

expected_mach_service="$(awk -F'"' '/machServiceName/ {print $2; exit}' "$CONSTANTS_FILE")"
expected_daemon_plist="$(awk -F'"' '/daemonPlistName/ {print $2; exit}' "$CONSTANTS_FILE")"
expected_helper_exec="$(awk -F'"' '/helperExecutableName/ {print $2; exit}' "$CONSTANTS_FILE")"
expected_helper_identifier="$(awk -F'"' '/helperCodeSigningIdentifier/ {print $2; exit}' "$CONSTANTS_FILE")"

[[ -n "$expected_mach_service" ]] || fail "could not resolve expected mach service name"
[[ -n "$expected_daemon_plist" ]] || fail "could not resolve expected daemon plist name"
[[ -n "$expected_helper_exec" ]] || fail "could not resolve expected helper executable name"
[[ -n "$expected_helper_identifier" ]] || fail "could not resolve expected helper code-signing identifier"

helper_rel="Contents/Library/HelperTools/${expected_helper_exec}"
daemon_rel="Contents/Library/LaunchDaemons/${expected_daemon_plist}"
helper_path="${APP_PATH}/${helper_rel}"
daemon_plist_path="${APP_PATH}/${daemon_rel}"
app_plist_path="${APP_PATH}/Contents/Info.plist"

[[ -f "$helper_path" ]] || fail "embedded helper missing at '${helper_rel}'"
[[ -f "$daemon_plist_path" ]] || fail "launch daemon plist missing at '${daemon_rel}'"
[[ -f "$app_plist_path" ]] || fail "app Info.plist missing"

codesign --verify --deep --strict --verbose=2 "$APP_PATH" >/dev/null 2>&1 || fail "codesign verification failed for app"
codesign --verify --strict --verbose=2 "$helper_path" >/dev/null 2>&1 || fail "codesign verification failed for helper"

helper_codesign_output="$(codesign -dvvv "$helper_path" 2>&1)"
helper_identifier="$(awk -F= '/^Identifier=/{print $2; exit}' <<<"$helper_codesign_output")"
if [[ -n "$EXPECTED_TEAM_ID" ]]; then
  [[ "$helper_identifier" == "$expected_helper_identifier" ]] || fail "helper identifier mismatch: expected '${expected_helper_identifier}', got '${helper_identifier}'"
else
  if [[ "$helper_identifier" != "$expected_helper_identifier" ]] && [[ ! "$helper_identifier" =~ ^${expected_helper_identifier}-[[:xdigit:]]{40}$ ]]; then
    fail "helper identifier mismatch: expected '${expected_helper_identifier}' or ad-hoc variant, got '${helper_identifier}'"
  fi
fi

plist_label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$daemon_plist_path" 2>/dev/null || true)"
plist_bundle_program="$(/usr/libexec/PlistBuddy -c 'Print :BundleProgram' "$daemon_plist_path" 2>/dev/null || true)"
plist_mach_service="$(/usr/libexec/PlistBuddy -c "Print :MachServices:${expected_mach_service}" "$daemon_plist_path" 2>/dev/null || true)"

[[ "$plist_label" == "$expected_mach_service" ]] || fail "launchd Label mismatch: expected '${expected_mach_service}', got '${plist_label}'"
[[ "$plist_bundle_program" == "$helper_rel" ]] || fail "BundleProgram mismatch: expected '${helper_rel}', got '${plist_bundle_program}'"
if [[ "$plist_mach_service" != "true" && "$plist_mach_service" != "1" ]]; then
  fail "MachServices entry for '${expected_mach_service}' must be true"
fi

if [[ -n "$EXPECTED_TEAM_ID" ]]; then
  app_codesign_output="$(codesign -dvvv "$APP_PATH" 2>&1)"
  app_team="$(awk -F= '/^TeamIdentifier=/{print $2; exit}' <<<"$app_codesign_output")"
  helper_team="$(awk -F= '/^TeamIdentifier=/{print $2; exit}' <<<"$helper_codesign_output")"
  [[ "$app_team" == "$EXPECTED_TEAM_ID" ]] || fail "app TeamIdentifier mismatch: expected '${EXPECTED_TEAM_ID}', got '${app_team}'"
  [[ "$helper_team" == "$EXPECTED_TEAM_ID" ]] || fail "helper TeamIdentifier mismatch: expected '${EXPECTED_TEAM_ID}', got '${helper_team}'"

  configured_team_id="$(/usr/libexec/PlistBuddy -c 'Print :AwakeBarTeamID' "$app_plist_path" 2>/dev/null || true)"
  [[ "$configured_team_id" == "$EXPECTED_TEAM_ID" ]] || fail "AwakeBarTeamID mismatch in Info.plist: expected '${EXPECTED_TEAM_ID}', got '${configured_team_id}'"
fi

echo "smoke-check passed for '${APP_PATH}'"
echo "  helper identifier: ${helper_identifier}"
echo "  mach service: ${expected_mach_service}"
if [[ -n "$EXPECTED_TEAM_ID" ]]; then
  echo "  team id: ${EXPECTED_TEAM_ID}"
fi
