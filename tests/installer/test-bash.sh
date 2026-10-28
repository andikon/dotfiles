#!/usr/bin/env bash
set -eo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
TEMP_BASE=$(CDPATH= cd -- "${TMPDIR:-/tmp}" && pwd -P)
FIXTURE=$(mktemp -d "$TEMP_BASE/dotfiles-tests.XXXXXXXX")
cleanup() { case "$FIXTURE" in "$TEMP_BASE"/dotfiles-tests.*) rm -rf -- "$FIXTURE" ;; esac; }
trap cleanup EXIT
export DOTFILES_TEST_PLATFORM=linux
unset WSL_DISTRO_NAME
HOME_FIXTURE="$FIXTURE/home with spaces & apostrophe's {test}"
LOG=$FIXTURE/output
run() { if ! "$BASH" "$ROOT/install.sh" "$@" > "$LOG" 2>&1; then cat "$LOG" >&2; return 1; fi; }
assert_file() { [ -f "$1" ] || { echo "Missing file: $1" >&2; exit 1; }; }
assert_missing() { if [ -e "$1" ] || [ -L "$1" ]; then echo "Unexpected entry: $1" >&2; exit 1; fi; }
latest_backup() { find "$1/.local/state/dotfiles/backups" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1; }

run --only nvim --dry-run --home "$HOME_FIXTURE"
assert_missing "$HOME_FIXTURE"
mkdir -p "$HOME_FIXTURE/.config/nvim" "$HOME_FIXTURE/.config/Code/User"
echo original > "$HOME_FIXTURE/.config/nvim/obsolete.txt"
echo '{ "old": true }' > "$HOME_FIXTURE/.config/Code/User/settings.json"
echo keep > "$HOME_FIXTURE/.config/Code/User/unrelated.txt"
run --only nvim,vscode --yes --skip-dependencies --home "$HOME_FIXTURE"
assert_missing "$HOME_FIXTURE/.config/nvim/obsolete.txt"
assert_file "$HOME_FIXTURE/.config/nvim/init.lua"
grep -qx keep "$HOME_FIXTURE/.config/Code/User/unrelated.txt"
backup=$(latest_backup "$HOME_FIXTURE")
run --restore "$backup" --yes --home "$HOME_FIXTURE"
grep -qx original "$HOME_FIXTURE/.config/nvim/obsolete.txt"
grep -qx '{ "old": true }' "$HOME_FIXTURE/.config/Code/User/settings.json"
assert_missing "$HOME_FIXTURE/.config/Code/User/keybindings.json"
run --restore "$backup" --yes --home "$HOME_FIXTURE"
echo 'PASS: preview, replacement, stale-file removal, shared ownership and repeated restore.'

# A top-level Stow link must move as a link, leaving its source untouched.
mkdir -p "$FIXTURE/original" "$FIXTURE/links/.config"
echo source > "$FIXTURE/original/keep.txt"
ln -s "$FIXTURE/original" "$FIXTURE/links/.config/nvim"
if [ -L "$FIXTURE/links/.config/nvim" ]; then
  run --only nvim --yes --skip-dependencies --home "$FIXTURE/links"
  grep -qx source "$FIXTURE/original/keep.txt"
  run --restore "$(latest_backup "$FIXTURE/links")" --yes --home "$FIXTURE/links"
  [ -L "$FIXTURE/links/.config/nvim" ]
  echo 'PASS: Stow symlink replacement and restoration leave the source untouched.'
else echo 'SKIP: this host cannot create Unix symlinks; Linux/macOS CI exercises this case.'
fi

if "$BASH" "$ROOT/install.sh" --only does-not-exist --yes --home "$HOME_FIXTURE" > "$LOG" 2>&1; then echo 'Unknown tool accepted.' >&2; exit 1; fi
if DOTFILES_TEST_PLATFORM=wsl "$BASH" "$ROOT/install.sh" --only hypr --dry-run --home "$HOME_FIXTURE" > "$LOG" 2>&1; then echo 'Desktop tool accepted in WSL.' >&2; exit 1; fi
mkdir -p "$HOME_FIXTURE/.local/state/dotfiles/installer.lock"
if "$BASH" "$ROOT/install.sh" --only nvim --yes --home "$HOME_FIXTURE" > "$LOG" 2>&1; then echo 'Concurrent install accepted.' >&2; exit 1; fi
rmdir "$HOME_FIXTURE/.local/state/dotfiles/installer.lock"
echo 'PASS: invalid selections, WSL applicability and concurrent installs are refused.'

# macOS replaces the native Ghostty directory and removes conflicting XDG files.
MAC_HOME=$FIXTURE/mac
mkdir -p "$MAC_HOME/.config/ghostty"
echo old > "$MAC_HOME/.config/ghostty/config"
DOTFILES_TEST_PLATFORM=macos run --only ghostty --yes --skip-dependencies --home "$MAC_HOME"
assert_file "$MAC_HOME/Library/Application Support/com.mitchellh.ghostty/config"
assert_missing "$MAC_HOME/.config/ghostty/config"
DOTFILES_TEST_PLATFORM=macos run --restore "$(latest_backup "$MAC_HOME")" --yes --home "$MAC_HOME"
grep -qx old "$MAC_HOME/.config/ghostty/config"
echo 'PASS: macOS native destinations and conflicting Ghostty configs restore correctly.'

# Load transaction functions to inject a failure after one live target changes.
(
  . "$ROOT/installer/bash/catalog.sh"
  . "$ROOT/installer/bash/transaction.sh"
  HOME_DIR=$HOME_FIXTURE; CONFIG_DIR=$HOME_DIR/.config; STATE_DIR=$HOME_DIR/.local/state/dotfiles
  VSCODE_DIR=$CONFIG_DIR/Code/User; NVIM_DIR=$CONFIG_DIR/nvim; PLATFORM=linux
  new_run
  fail_once=true
  mv() {
    local last= arg
    for arg in "$@"; do last=$arg; done
    if $fail_once && [ "$last" = "$VSCODE_DIR/keybindings.json" ]; then fail_once=false; return 1; fi
    command mv "$@"
  }
  if install_tool vscode; then echo 'Injected failure was ignored.' >&2; exit 1; fi
  grep -qx '{ "old": true }' "$VSCODE_DIR/settings.json"
  assert_missing "$VSCODE_DIR/keybindings.json"
  [ -z "$(find "$VSCODE_DIR" -name '.dotfiles-stage.*' -print)" ]
)
echo 'PASS: a mid-apply failure rolls the complete tool back and removes staging files.'

(
  . "$ROOT/installer/bash/catalog.sh"
  . "$ROOT/installer/bash/transaction.sh"
  HOME_DIR=$HOME_FIXTURE; CONFIG_DIR=$HOME_DIR/.config; STATE_DIR=$HOME_DIR/.local/state/dotfiles
  VSCODE_DIR=$CONFIG_DIR/Code/User; NVIM_DIR=$CONFIG_DIR/nvim; PLATFORM=linux; DRY_RUN=false
  new_run
  mv() {
    local source= destination= arg
    for arg in "$@"; do
      [ "$arg" != -- ] || continue
      if [ -z "$source" ]; then source=$arg; else destination=$arg; fi
    done
    if [ "$source" = "$VSCODE_DIR/settings.json" ] && [ "${destination##*/}" = previous ]; then
      printf partial > "$destination"
      return 1
    fi
    command mv "$@"
  }
  if install_tool vscode; then echo 'Partial backup failure was ignored.' >&2; exit 1; fi
  grep -qx '{ "old": true }' "$VSCODE_DIR/settings.json"
  TX_STATUS[0]=intent
  write_journal
  restore_run "$RUN_DIR"
  grep -qx '{ "old": true }' "$VSCODE_DIR/settings.json"
)
echo 'PASS: partial backup failures and interrupted-backup recovery preserve the original.'

# Package managers are substituted; no real software is installed by this test.
MOCK_BIN=$FIXTURE/bin
mkdir "$MOCK_BIN"
cat > "$MOCK_BIN/brew" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PACKAGE_LOG"
MOCK
chmod +x "$MOCK_BIN/brew"
PACKAGE_LOG=$FIXTURE/packages
export PACKAGE_LOG
(
  . "$ROOT/installer/bash/catalog.sh"
  PLATFORM=macos; PATH=$MOCK_BIN:$PATH
  install_dependencies fish
)
grep -qx 'install fish' "$PACKAGE_LOG"

# An old Neovim must be visible and skipped when --skip-missing is selected.
cat > "$MOCK_BIN/nvim" <<'MOCK'
#!/usr/bin/env bash
echo 'NVIM v0.11.0'
MOCK
chmod +x "$MOCK_BIN/nvim"
PATH="$MOCK_BIN:$PATH" run --only nvim --yes --skip-missing --home "$FIXTURE/old-version"
grep -q 'Too old' "$LOG"
assert_missing "$FIXTURE/old-version"
echo 'PASS: package-manager dispatch is isolated and incompatible versions are skipped.'

# Cancellation via numbered fallback leaves settings and state unchanged.
printf 'none\n' | "$BASH" "$ROOT/install.sh" --only tmux --skip-dependencies --home "$FIXTURE/cancel" > "$LOG" 2>&1
assert_missing "$FIXTURE/cancel"
echo 'PASS: cancelling configuration selection makes no changes.'

printf '1, 2\nno\n' | "$BASH" "$ROOT/install.sh" --only fish,tmux --skip-dependencies --home "$FIXTURE/numbered" > "$LOG" 2>&1
assert_missing "$FIXTURE/numbered"
grep -q 'Install/replace: fish tmux' "$LOG"
echo 'PASS: numbered selection accepts spaces and final confirmation can cancel.'

ALL_HOME=$FIXTURE/all-linux-tools
run --only nvim,fish,tmux,shell-tools,ghostty,vscode,idea,hypr,waybar,swaync,wofi,cava --yes --skip-dependencies --home "$ALL_HOME"
assert_file "$ALL_HOME/.ideavimrc"
assert_file "$ALL_HOME/.tmux.conf"
assert_file "$ALL_HOME/.config/hypr/hyprland.conf"
assert_file "$ALL_HOME/.config/cava/waybar_raw.conf"
[ -x "$ALL_HOME/.local/bin/create_tmux_session.sh" ]
[ -x "$ALL_HOME/.config/waybar/scripts/weather.sh" ]
echo 'PASS: every supported Linux configuration stages, including dotfiles and executable helpers.'

# Simulate the two remote downloads with a local archive; assert commit pinning.
SNAPSHOT=$FIXTURE/snapshot
mkdir -p "$SNAPSHOT/dotfiles-fixture"
cp -R "$ROOT/install.sh" "$ROOT/installer" "$ROOT/catalog" "$ROOT/config" "$SNAPSHOT/dotfiles-fixture/"
ARCHIVE_FIXTURE=$FIXTURE/snapshot.tar.gz
tar -czf "$ARCHIVE_FIXTURE" -C "$SNAPSHOT" dotfiles-fixture
CURL_LOG=$FIXTURE/curl.log
export ARCHIVE_FIXTURE CURL_LOG
cat > "$MOCK_BIN/curl" <<'MOCK'
#!/usr/bin/env bash
url= out=
while [ "$#" -gt 0 ]; do
  case "$1" in -o) out=$2; shift 2 ;; https://*) url=$1; shift ;; *) shift ;; esac
done
printf '%s\n' "$url" >> "$CURL_LOG"
case "$url" in
  https://api.github.com/*) printf '%040d' 1 > "$out" ;;
  https://github.com/*/archive/0000000000000000000000000000000000000001.tar.gz) cp "$ARCHIVE_FIXTURE" "$out" ;;
  *) exit 22 ;;
esac
MOCK
chmod +x "$MOCK_BIN/curl"
PATH="$MOCK_BIN:$PATH" run --remote --ref test-branch --only fish --yes --skip-dependencies --home "$FIXTURE/remote"
assert_file "$FIXTURE/remote/.config/fish/config.fish"
grep -q '/commits/test-branch$' "$CURL_LOG"
grep -q '/archive/0000000000000000000000000000000000000001.tar.gz$' "$CURL_LOG"
cat > "$MOCK_BIN/curl" <<'MOCK'
#!/usr/bin/env bash
exit 22
MOCK
if PATH="$MOCK_BIN:$PATH" "$BASH" "$ROOT/install.sh" --remote --only fish --yes --home "$FIXTURE/download-failed" > "$LOG" 2>&1; then echo 'Failed download was ignored.' >&2; exit 1; fi
assert_missing "$FIXTURE/download-failed"
echo 'PASS: clone-free bootstrap pins a commit, and failed downloads leave configs untouched.'
