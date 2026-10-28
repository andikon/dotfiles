#!/usr/bin/env bash
set -eo pipefail
umask 077
ROOT=; ONLY=; YES=false; DRY_RUN=false; SKIP_DEPS=false; SKIP_MISSING=false; HOME_OPTION=; RESTORE=; VSCODE_OPTION=
LOCK_HELD=false; LOCK_DIR=
usage() {
  cat <<'USAGE'
Usage: bash install.sh [options]
  --only nvim,tmux       Limit detection and configuration selection
  --yes                 Apply the explicit --only list without prompts
  --skip-dependencies   Leave software installation to you
  --skip-missing        Skip configs whose required tools are unavailable
  --dry-run             Inspect tools and destinations without changes
  --home /path          Stage under a separate home (ignores XDG overrides)
  --vscode-dir /path    Select a VS Code User directory
  --restore /path       Restore an installer backup run
  --ref tag-or-commit    Remote bootstrap revision (default: main)
  --remote              Download a snapshot even from a local checkout
  --help                Show this help
USAGE
}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root|--only|--home|--restore|--vscode-dir)
      [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
      case "$1" in --root) ROOT=$2 ;; --only) ONLY=$2 ;; --home) HOME_OPTION=$2 ;; --restore) RESTORE=$2 ;; --vscode-dir) VSCODE_OPTION=$2 ;; esac
      shift 2 ;;
    --yes) YES=true; shift ;;
    --skip-dependencies) SKIP_DEPS=true; shift ;;
    --skip-missing) SKIP_MISSING=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[ -n "$ROOT" ] || ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
ROOT=$(CDPATH= cd -- "$ROOT" && pwd -P)
. "$ROOT/installer/bash/catalog.sh"
. "$ROOT/installer/bash/transaction.sh"
. "$ROOT/installer/bash/interface.sh"
cleanup_installer() {
  if $LOCK_HELD; then rmdir "$LOCK_DIR" 2>/dev/null || true; fi
}
trap cleanup_installer EXIT
trap 'exit 130' INT TERM HUP
case "${DOTFILES_TEST_PLATFORM:-$(uname -s)}" in
  Darwin|macos) PLATFORM=macos ;;
  Linux|linux)
    PLATFORM=linux
    if [ -n "${WSL_DISTRO_NAME:-}" ] || { [ -r /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease; }; then PLATFORM=wsl; fi ;;
  wsl) PLATFORM=wsl ;;
  *) echo 'Use install.ps1 on Windows.' >&2; exit 2 ;;
esac
HOME_DIR=${HOME_OPTION:-$HOME}
normalize_path "$HOME_DIR"; HOME_DIR=$NORMALIZED
if [ -n "$HOME_OPTION" ]; then
  CONFIG_DIR=$HOME_DIR/.config; STATE_DIR=$HOME_DIR/.local/state/dotfiles; NVIM_NAME=nvim
else
  CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME_DIR/.config}; STATE_DIR=${XDG_STATE_HOME:-$HOME_DIR/.local/state}/dotfiles; NVIM_NAME=${NVIM_APPNAME:-nvim}
fi
case "$NVIM_NAME" in /*|../*|*/../*|*/..|..) echo 'NVIM_APPNAME must be a relative name without parent traversal.' >&2; exit 2 ;; esac
normalize_path "$CONFIG_DIR"; CONFIG_DIR=$NORMALIZED
normalize_path "$STATE_DIR"; STATE_DIR=$NORMALIZED
normalize_path "$CONFIG_DIR/$NVIM_NAME"; NVIM_DIR=$NORMALIZED
if [ -n "$VSCODE_OPTION" ]; then VSCODE_DIR=$VSCODE_OPTION
elif [ "$PLATFORM" = macos ]; then VSCODE_DIR=$HOME_DIR/Library/Application\ Support/Code/User
elif [ -z "$HOME_OPTION" ] && [ -n "${VSCODE_PORTABLE:-}" ]; then VSCODE_DIR=$VSCODE_PORTABLE/user-data/User
else VSCODE_DIR=$CONFIG_DIR/Code/User
fi
normalize_path "$VSCODE_DIR"; VSCODE_DIR=$NORMALIZED
GREEN=; RED=; CYAN=; RESET=
if [ -t 1 ] && [ -z "${NO_COLOR+x}" ] && [ "${TERM:-dumb}" != dumb ]; then GREEN=$'\033[32m'; RED=$'\033[31m'; CYAN=$'\033[36m'; RESET=$'\033[0m'; fi
acquire_lock() {
  # Validate parents before creating state; a stale lock requires an explicit removal.
  assert_target "$STATE_DIR/installer.lock" || return 1
  mkdir -p "$STATE_DIR" || return 1
  LOCK_DIR=$STATE_DIR/installer.lock
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then echo "Another installer holds $LOCK_DIR. If it was interrupted, verify it has stopped before removing the lock directory." >&2; return 1; fi
  LOCK_HELD=true
}
if [ -n "$RESTORE" ]; then
  if ! $DRY_RUN; then
    if ! $YES; then read_answer 'Restore this backup? Type yes: '; [ "$ANSWER" = yes ] || { echo 'Cancelled.'; exit 0; }; fi
    acquire_lock
  fi
  restore_run "$RESTORE"
  exit 0
fi
if $YES && [ -z "$ONLY" ]; then echo '--yes requires an explicit --only list.' >&2; exit 2; fi
load_catalog
ACTIVE=(); REQUESTED=()
if [ -n "$ONLY" ]; then
  IFS=, read -r -a REQUESTED <<< "$ONLY"
  for id in "${REQUESTED[@]}"; do
    if ! tool_index "$id" || ! contains_id "${TOOL_PLATFORMS[$LOOKUP_INDEX]}" "$PLATFORM"; then echo "Unknown or unsupported $PLATFORM tool: $id" >&2; exit 2; fi
  done
fi
for ((i=0; i<${#TOOL_IDS[@]}; i++)); do
  contains_id "${TOOL_PLATFORMS[$i]}" "$PLATFORM" || continue
  if [ -n "$ONLY" ] && ! contains_id "$ONLY" "${TOOL_IDS[$i]}"; then continue; fi
  ACTIVE+=("$i")
done
printf '\n%sDotfiles - %s%s\n1/4 - Tools and dependencies\n' "$CYAN" "$PLATFORM" "$RESET"
STATUS_IDS=(); STATUS_READY=(); STATUS_TEXT=(); STATUS_DETAILS=(); REQUIRED_IDS=()
for i in "${ACTIVE[@]}"; do
  cache_status "${TOOL_IDS[$i]}"; print_status "$STATUS_INDEX" "${TOOL_LABELS[$i]}"
  REQUIRED_IDS+=("${TOOL_IDS[$i]}")
  deps=(); IFS=, read -r -a deps <<< "${TOOL_REQS[$i]}"
  for id in "${deps[@]}"; do [ "$id" != - ] || continue; cache_status "$id"; print_status "$STATUS_INDEX" "$id" '  required: '; REQUIRED_IDS+=("$id"); done
  deps=(); IFS=, read -r -a deps <<< "${TOOL_OPTS[$i]}"
  for id in "${deps[@]}"; do [ "$id" != - ] || continue; cache_status "$id"; print_status "$STATUS_INDEX" "$id" '  optional: '; done
done
printf '\n%s2/4 - Missing dependencies%s\n' "$CYAN" "$RESET"
MENU_IDS=(); MENU_LABELS=(); MENU_DEFAULTS=()
for ((i=0; i<${#STATUS_IDS[@]}; i++)); do
  [ "${STATUS_READY[$i]}" != true ] || continue
  id=${STATUS_IDS[$i]}; default=false
  for required in "${REQUIRED_IDS[@]}"; do if [ "$id" = "$required" ]; then default=true; break; fi; done
  MENU_IDS+=("$id"); MENU_LABELS+=("$id"); MENU_DEFAULTS+=("$default")
done
if [ "${#MENU_IDS[@]}" -gt 0 ] && ! $YES && ! $SKIP_DEPS && ! $DRY_RUN; then
  printf '1. Install selected missing dependencies\n2. I will handle dependencies myself (default)\n3. Skip tools with missing requirements\n'
  read_answer 'Choose 1, 2, or 3: '
  case "$ANSWER" in
    1)
      select_items 'Select software to install'
      install_dependencies "${SELECTED[@]}"
      STATUS_IDS=(); STATUS_READY=(); STATUS_TEXT=(); STATUS_DETAILS=()
      for id in "${SELECTED[@]}"; do cache_status "$id"; print_status "$STATUS_INDEX" "$id"; done ;;
    3) SKIP_MISSING=true ;;
    ''|2) echo 'Continue without installing software.' ;;
    *) echo 'Cancelled: choose a displayed dependency option.' >&2; exit 2 ;;
  esac
else echo 'No software will be installed.'
fi
printf '\n%s3/4 - Configurations%s\n' "$CYAN" "$RESET"
MENU_IDS=(); MENU_LABELS=(); MENU_DEFAULTS=()
for i in "${ACTIVE[@]}"; do
  id=${TOOL_IDS[$i]}; ready=true
  cache_status "$id"; [ "${STATUS_READY[$STATUS_INDEX]}" = true ] || ready=false
  deps=(); IFS=, read -r -a deps <<< "${TOOL_REQS[$i]}"
  for dep in "${deps[@]}"; do [ "$dep" != - ] || continue; cache_status "$dep"; [ "${STATUS_READY[$STATUS_INDEX]}" = true ] || ready=false; done
  get_targets "$id"
  action=INSTALL
  for destination in "${TARGET_DESTS[@]}"; do if entry_exists "$destination"; then action=REPLACE; fi; done
  availability=ready; $ready || availability='requirements missing; config can be staged'
  printf '%s: %s (%s)\n' "${TOOL_LABELS[$i]}" "$action" "$availability"
  for ((j=0; j<${#TARGET_DESTS[@]}; j++)); do
    assert_target "${TARGET_DESTS[$j]}"
    printf '  %s [%s]\n' "${TARGET_DESTS[$j]}" "${TARGET_KINDS[$j]}"
  done
  if $SKIP_MISSING && ! $ready; then echo '  SKIPPED: requirements missing'; continue; fi
  default=$ready
  if [ "${TOOL_GROUPS[$i]}" != cli ] && [ "$PLATFORM" != macos ] && [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then default=false; fi
  MENU_IDS+=("$id"); MENU_LABELS+=("${TOOL_LABELS[$i]} - $action ($availability)"); MENU_DEFAULTS+=("$default")
done
if $DRY_RUN; then echo; echo 'Preview only: no packages, configurations or backups changed.'; exit 0; fi
if $YES; then SELECTED=("${MENU_IDS[@]}"); else select_items 'Select configurations to install or replace'; fi
if [ "${#SELECTED[@]}" -eq 0 ]; then echo 'Nothing selected.'; exit 0; fi
printf '\n%s4/4 - Review%s\n' "$CYAN" "$RESET"
printf 'Install/replace: %s\n' "${SELECTED[*]}"
printf 'Existing targets will be moved into a timestamped backup under %s/backups.\n' "$STATE_DIR"
if ! $YES; then read_answer 'Apply these changes? Type yes: '; [ "$ANSWER" = yes ] || { echo 'Cancelled.'; exit 0; }; fi
acquire_lock
new_run
failures=0
for id in "${SELECTED[@]}"; do
  if install_tool "$id"; then printf '%sINSTALLED: %s%s\n' "$GREEN" "$id" "$RESET"
  else printf 'FAILED: %s (see diagnostics above)\n' "$id" >&2; failures=$((failures+1))
  fi
done
printf '\nBackup run: %s\n' "$RUN_DIR"
for i in "${ACTIVE[@]}"; do
  chosen=false
  for id in "${SELECTED[@]}"; do [ "$id" != "${TOOL_IDS[$i]}" ] || chosen=true; done
  $chosen || printf 'SKIPPED: %s\n' "${TOOL_IDS[$i]}"
done
echo 'Reopen affected applications. See docs/configuration.md for first-launch and restore commands.'
[ "$failures" -eq 0 ]
