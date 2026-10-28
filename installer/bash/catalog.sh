load_catalog() {
  TOOL_IDS=(); TOOL_LABELS=(); TOOL_PLATFORMS=(); TOOL_COMMANDS=(); TOOL_REQS=(); TOOL_OPTS=(); TOOL_GROUPS=()
  local id label platforms command required optional group
  while IFS=$'\t' read -r id label platforms command required optional group; do
    [ "$id" = id ] && continue
    TOOL_IDS+=("$id"); TOOL_LABELS+=("$label"); TOOL_PLATFORMS+=("$platforms"); TOOL_COMMANDS+=("$command")
    TOOL_REQS+=("$required"); TOOL_OPTS+=("$optional"); TOOL_GROUPS+=("$group")
  done < "$ROOT/catalog/tools.tsv"
}

contains_id() { case ",$1," in *",$2,"*) return 0 ;; *) return 1 ;; esac; }
tool_index() {
  local i
  LOOKUP_INDEX=-1
  for ((i=0; i<${#TOOL_IDS[@]}; i++)); do
    if [ "${TOOL_IDS[$i]}" = "$1" ]; then LOOKUP_INDEX=$i; return 0; fi
  done
  return 1
}

normalize_path() {
  local path=$1 part joined=
  local pieces=() result=()
  case "$path" in *$'\t'*|*$'\n'*|*$'\r'*) echo 'Paths cannot contain tabs or newlines.' >&2; return 1 ;; esac
  case "$path" in /*) ;; *) path=$PWD/$path ;; esac
  IFS=/ read -r -a pieces <<< "$path"
  for part in "${pieces[@]}"; do
    case "$part" in ''|.) ;; ..) if [ "${#result[@]}" -gt 0 ]; then unset "result[$((${#result[@]}-1))]"; fi ;; *) result+=("$part") ;; esac
  done
  for part in "${result[@]}"; do joined=$joined/$part; done
  NORMALIZED=${joined:-/}
}

find_command() {
  local id=$1 command=$1 candidate
  FOUND=
  if tool_index "$id"; then command=${TOOL_COMMANDS[$LOOKUP_INDEX]}; fi
  FOUND=$(command -v "$command" 2>/dev/null) || FOUND=
  [ -z "$FOUND" ] || return 0
  if [ "$PLATFORM" = macos ]; then
    case "$id" in
      ghostty) candidate='/Applications/Ghostty.app/Contents/MacOS/ghostty' ;;
      vscode) candidate='/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code' ;;
      idea) candidate='/Applications/IntelliJ IDEA.app/Contents/MacOS/idea' ;;
      *) candidate= ;;
    esac
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then FOUND=$candidate; fi
  fi
  [ -n "$FOUND" ]
}

version_at_least() {
  local actual=$1 minimum=$2 a=() b=() i av bv
  IFS=. read -r -a a <<< "$actual"
  IFS=. read -r -a b <<< "$minimum"
  for i in 0 1 2; do
    av=${a[$i]:-0}; bv=${b[$i]:-0}
    [ "$av" -le "$bv" ] || return 0
    [ "$av" -ge "$bv" ] || return 1
  done
  return 0
}

detect_status() {
  local id=$1 minimum=- text version agent command=$1 requirement required_version
  READY=false; STATUS='Not found'; DETAIL='Install manually or select a package'
  if [ "$id" = vscode-extensions ]; then
    local installed= extension missing=0
    if find_command vscode; then installed=$("$FOUND" --list-extensions 2>/dev/null) || installed=; fi
    while IFS= read -r extension; do
      [ -n "$extension" ] || continue
      if ! printf '%s\n' "$installed" | grep -Fxiq -- "$extension"; then missing=$((missing+1)); fi
    done < "$ROOT/config/vscode/common/extensions.txt"
    DETAIL="$missing configured VS Code extensions missing"
    if [ "$missing" -eq 0 ]; then READY=true; STATUS=Installed; fi
    return
  fi
  if tool_index "$id"; then command=${TOOL_COMMANDS[$LOOKUP_INDEX]}; fi
  while IFS=$'\t' read -r requirement required_version; do
    if [ "$requirement" = "$command" ]; then minimum=$required_version; break; fi
  done < "$ROOT/catalog/requirements.tsv"
  if [ "$id" = agent ]; then
    for agent in codex claude copilot opencode; do
      if command -v "$agent" >/dev/null 2>&1; then READY=true; STATUS=Installed; DETAIL=$agent; return; fi
    done
    return
  fi
  if [ "$id" = font ]; then
    if { command -v fc-list >/dev/null 2>&1 && fc-list 2>/dev/null | grep -iq 'JetBrains.*Nerd'; } || compgen -G "$HOME_DIR/Library/Fonts/*JetBrains*Nerd*" >/dev/null; then
      READY=true; STATUS=Installed; DETAIL='JetBrains Mono Nerd Font'
    else DETAIL='Check the JetBrains Mono Nerd Font family in your terminal'; fi
    return
  fi
  if ! find_command "$id"; then return; fi
  DETAIL=$FOUND
  if [ "$minimum" != - ]; then
    text=$("$FOUND" --version 2>&1) || { STATUS='Check version'; DETAIL="Needs $minimum+ ($FOUND)"; return; }
    if [[ "$text" =~ ([0-9]+)\.([0-9]+)(\.([0-9]+))? ]]; then
      version=${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[4]:-0}
      if ! version_at_least "$version" "$minimum"; then STATUS='Too old'; DETAIL="$version; needs $minimum+"; return; fi
      DETAIL="$version ($FOUND)"
    else STATUS='Check version'; DETAIL="Needs $minimum+ ($FOUND)"; return
    fi
  fi
  READY=true; STATUS=Installed
}

cache_status() {
  local id=$1 i
  STATUS_INDEX=-1
  for ((i=0; i<${#STATUS_IDS[@]}; i++)); do
    if [ "${STATUS_IDS[$i]}" = "$id" ]; then STATUS_INDEX=$i; return; fi
  done
  detect_status "$id"
  STATUS_INDEX=${#STATUS_IDS[@]}
  STATUS_IDS+=("$id"); STATUS_READY+=("$READY"); STATUS_TEXT+=("$STATUS"); STATUS_DETAILS+=("$DETAIL")
}

resolve_destination() {
  local raw=$1 template=$1
  template=${template//\{HOME\}/}; template=${template//\{CONFIG\}/}; template=${template//\{NVIM\}/}; template=${template//\{VSCODE\}/}
  case "$template" in *'{'*|*'}'*) echo "Unknown destination variable: $1" >&2; return 1 ;; esac
  raw=${raw//\{HOME\}/"$HOME_DIR"}
  raw=${raw//\{CONFIG\}/"$CONFIG_DIR"}
  raw=${raw//\{NVIM\}/"$NVIM_DIR"}
  raw=${raw//\{VSCODE\}/"$VSCODE_DIR"}
  normalize_path "$raw" || return 1
  DESTINATION=$NORMALIZED
}

get_targets() {
  local tool=$1 id platforms kind source destination
  TARGET_KINDS=(); TARGET_SOURCES=(); TARGET_DESTS=()
  while IFS=$'\t' read -r id platforms kind source destination; do
    [ "$id" = "$tool" ] || continue
    contains_id "$platforms" "$PLATFORM" || continue
    resolve_destination "$destination" || return 1
    TARGET_KINDS+=("$kind"); TARGET_DESTS+=("$DESTINATION"); TARGET_SOURCES+=("$ROOT/$source")
  done < "$ROOT/catalog/targets.tsv"
}

find_package_manager() {
  MANAGER=
  if [ "$PLATFORM" = macos ]; then
    if command -v brew >/dev/null 2>&1; then MANAGER=brew; fi
  else
    local manager
    for manager in apt-get dnf pacman; do
      if command -v "$manager" >/dev/null 2>&1; then MANAGER=$manager; break; fi
    done
  fi
}

install_dependencies() {
  local id row_id winget brew apt dnf pacman package
  local args=() elevate=()
  find_package_manager
  for id in "$@"; do
    if [ "$id" = vscode-extensions ]; then
      if ! find_command vscode; then echo 'Install VS Code first, then rerun for extensions.'; continue; fi
      local code=$FOUND extension
      while IFS= read -r extension; do
        [ -n "$extension" ] || continue
        if ! "$code" --install-extension "$extension"; then echo "Could not install extension $extension" >&2; fi
      done < "$ROOT/config/vscode/common/extensions.txt"
      continue
    fi
    package=-
    while IFS=$'\t' read -r row_id winget brew apt dnf pacman; do
      [ "$row_id" = "$id" ] || continue
      case "$MANAGER" in brew) package=$brew ;; apt-get) package=$apt ;; dnf) package=$dnf ;; pacman) package=$pacman ;; esac
      break
    done < "$ROOT/catalog/packages.tsv"
    if [ -z "$MANAGER" ] || [ "$package" = - ]; then
      printf 'MANUAL: %s (see docs/installation.md)\n' "$id"
      continue
    fi
    args=(); elevate=()
    read -r -a args <<< "$package"
    if [ "$MANAGER" != brew ] && [ "$(id -u)" -ne 0 ]; then
      if ! command -v sudo >/dev/null 2>&1; then printf 'MANUAL: %s requires installation privileges.\n' "$id"; continue; fi
      elevate=(sudo)
    fi
    printf 'Installing %s with %s...\n' "$id" "$MANAGER"
    case "$MANAGER" in
      brew) if ! brew install "${args[@]}"; then printf 'FAILED: %s; install it manually.\n' "$id" >&2; fi ;;
      apt-get) if ! "${elevate[@]}" apt-get install -y "${args[@]}"; then printf 'FAILED: %s; run apt-get update if needed, then install manually.\n' "$id" >&2; fi ;;
      dnf) if ! "${elevate[@]}" dnf install -y "${args[@]}"; then printf 'FAILED: %s; install it manually.\n' "$id" >&2; fi ;;
      pacman) if ! "${elevate[@]}" pacman -S --needed --noconfirm "${args[@]}"; then printf 'FAILED: %s; update your system normally, then install manually.\n' "$id" >&2; fi ;;
    esac
  done
  hash -r
}
