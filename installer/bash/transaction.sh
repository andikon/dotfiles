entry_exists() { [ -e "$1" ] || [ -L "$1" ]; }

assert_target() {
  local path=$1 root inside=false parent
  normalize_path "$path" || return 1
  path=$NORMALIZED
  for root in "$HOME_DIR" "$CONFIG_DIR" "$VSCODE_DIR" "$STATE_DIR"; do
    if [ "$path" = "$root" ]; then echo "Refusing to replace a configuration root: $path" >&2; return 1; fi
    case "$path" in "$root"/*) inside=true ;; esac
  done
  $inside || { echo "Destination is outside allowed configuration locations: $path" >&2; return 1; }
  case "$STATE_DIR/" in "$path/"*) echo 'Destination contains installer backup state.' >&2; return 1 ;; esac
  case "$path/" in "$STATE_DIR/backups/"*) echo 'Destination overlaps installer backups.' >&2; return 1 ;; esac
  case "$path/" in "$ROOT/"* ) echo 'Destination overlaps the source repository.' >&2; return 1 ;; esac
  case "$ROOT/" in "$path/"* ) echo 'Destination contains the source repository.' >&2; return 1 ;; esac
  parent=${path%/*}
  while [ -n "$parent" ]; do
    if [ -L "$parent" ]; then echo "A destination parent is a symlink: $parent. Choose a physical location." >&2; return 1; fi
    parent=${parent%/*}
  done
}

remove_entry() {
  assert_target "$1" || return 1
  if [ -L "$1" ]; then rm -f -- "$1"; else rm -rf -- "$1"; fi
}

write_journal() {
  local i
  {
    printf 'version\t1\t%s\n' "$HOME_DIR"
    for ((i=0; i<${#TX_TOOLS[@]}; i++)); do
      printf '%s\t%s\t%s\t%s\t%s\n' "${TX_TOOLS[$i]}" "${TX_DESTS[$i]}" "${TX_BACKUPS[$i]}" "${TX_EXISTED[$i]}" "${TX_STATUS[$i]}"
    done
  } > "$RUN_DIR/manifest.tsv.tmp" || return 1
  mv -f -- "$RUN_DIR/manifest.tsv.tmp" "$RUN_DIR/manifest.tsv"
}

new_run() {
  mkdir -p "$STATE_DIR/backups" || return 1
  RUN_DIR=$(mktemp -d "$STATE_DIR/backups/$(date +%Y%m%d-%H%M%S).XXXXXXXX") || return 1
  TX_TOOLS=(); TX_DESTS=(); TX_BACKUPS=(); TX_EXISTED=(); TX_STATUS=()
  write_journal
}

rollback_entries() {
  local start=$1 i failed=false
  for ((i=${#TX_TOOLS[@]}-1; i>=start; i--)); do
    if [ "${TX_STATUS[$i]}" = intent ] && [ "${TX_EXISTED[$i]}" = yes ] && entry_exists "${TX_DESTS[$i]}"; then
      TX_STATUS[$i]=rolled-back
      continue
    fi
    if entry_exists "${TX_BACKUPS[$i]}"; then
      if ! remove_entry "${TX_DESTS[$i]}" || ! mv -- "${TX_BACKUPS[$i]}" "${TX_DESTS[$i]}"; then
        printf 'Rollback needs attention: %s (backup: %s)\n' "${TX_DESTS[$i]}" "${TX_BACKUPS[$i]}" >&2
        failed=true; continue
      fi
    elif [ "${TX_EXISTED[$i]}" = no ]; then
      if ! remove_entry "${TX_DESTS[$i]}"; then failed=true; continue; fi
    fi
    TX_STATUS[$i]=rolled-back
  done
  write_journal || failed=true
  ! $failed
}

cleanup_stages() {
  local stage
  for stage in "${STAGES[@]}"; do
    [ -n "$stage" ] || continue
    remove_entry "$stage" || return 1
  done
}

install_tool() {
  local tool=$1 i source destination kind stage backup existed index start=${#TX_TOOLS[@]} failed=false
  STAGES=()
  get_targets "$tool" || return 1
  # Complete staging before moving the first live configuration.
  for ((i=0; i<${#TARGET_DESTS[@]}; i++)); do
    source=${TARGET_SOURCES[$i]}; destination=${TARGET_DESTS[$i]}; kind=${TARGET_KINDS[$i]}; stage=
    if ! assert_target "$destination"; then cleanup_stages; return 1; fi
    if [ "$kind" != absent ]; then
      if [ ! -e "$source" ] || [ -L "$source" ] || [ -n "$(find "$source" -type l -print -quit)" ]; then
        echo "Missing source or source contains symlinks: $source" >&2; cleanup_stages; return 1
      fi
      if ! mkdir -p "${destination%/*}"; then cleanup_stages; return 1; fi
      stage=$(mktemp -d "${destination%/*}/.dotfiles-stage.XXXXXXXX") || { cleanup_stages; return 1; }
      STAGES+=("$stage")
      if ! cp -RP "$source" "$stage/value"; then cleanup_stages; return 1; fi
      if [ "$kind" = directory ]; then
        if ! find "$stage/value" -type f -name '*.sh' -exec chmod u+x {} +; then cleanup_stages; return 1; fi
      elif [ "${destination##*.}" = sh ]; then chmod u+x "$stage/value" || { cleanup_stages; return 1; }
      fi
    else STAGES+=("")
    fi
  done
  for ((i=0; i<${#TARGET_DESTS[@]}; i++)); do
    destination=${TARGET_DESTS[$i]}; stage=${STAGES[$i]}; index=${#TX_TOOLS[@]}; existed=no
    backup=$RUN_DIR/$(printf '%03d-%s' "$index" "$tool")/previous
    if entry_exists "$destination"; then existed=yes; fi
    TX_TOOLS+=("$tool"); TX_DESTS+=("$destination"); TX_BACKUPS+=("$backup"); TX_EXISTED+=("$existed"); TX_STATUS+=(intent)
    if ! write_journal; then failed=true; break; fi
    if [ "$existed" = yes ]; then
      if ! mkdir -p "${backup%/*}" || ! mv -- "$destination" "$backup"; then failed=true; break; fi
    fi
    TX_STATUS[$index]=backed-up
    if ! write_journal; then failed=true; break; fi
    if [ -n "$stage" ] && ! mv -- "$stage/value" "$destination"; then failed=true; break; fi
    TX_STATUS[$index]=installed
    if ! write_journal; then failed=true; break; fi
  done
  if $failed; then rollback_entries "$start" || true; cleanup_stages; return 1; fi
  cleanup_stages
}

restore_run() {
  local directory=$1 version number home tool destination backup existed status i saved
  normalize_path "$directory" || return 1
  RUN_DIR=$NORMALIZED
  case "$RUN_DIR" in "$STATE_DIR/backups/"*) ;; *) echo "Restore must name a run inside $STATE_DIR/backups" >&2; return 1 ;; esac
  TX_TOOLS=(); TX_DESTS=(); TX_BACKUPS=(); TX_EXISTED=(); TX_STATUS=()
  IFS=$'\t' read -r version number home < "$RUN_DIR/manifest.tsv" || return 1
  [ "$version" = version ] && [ "$number" = 1 ] && [ "$home" = "$HOME_DIR" ] || { echo 'Backup version or home does not match.' >&2; return 1; }
  while IFS=$'\t' read -r tool destination backup existed status; do
    [ "$tool" = version ] && continue
    assert_target "$destination" || return 1
    normalize_path "$backup" || return 1
    [ "$backup" = "$NORMALIZED" ] || { echo 'Noncanonical backup path.' >&2; return 1; }
    case "$backup" in "$RUN_DIR/"*) ;; *) echo 'Backup entry escapes its run directory.' >&2; return 1 ;; esac
    case "$existed" in yes|no) ;; *) echo 'Invalid backup entry.' >&2; return 1 ;; esac
    case "$status" in installed|backed-up|intent|restored|rolled-back) ;; *) echo 'Invalid backup status.' >&2; return 1 ;; esac
    if { [ "$status" = installed ] || [ "$status" = backed-up ]; } && [ "$existed" = yes ] && ! entry_exists "$backup"; then echo "Missing backup: $backup" >&2; return 1; fi
    if [ "$status" = intent ] && [ "$existed" = yes ] && ! entry_exists "$backup" && ! entry_exists "$destination"; then echo "Interrupted backup has neither original nor saved target: $destination" >&2; return 1; fi
    TX_TOOLS+=("$tool"); TX_DESTS+=("$destination"); TX_BACKUPS+=("$backup"); TX_EXISTED+=("$existed"); TX_STATUS+=("$status")
  done < "$RUN_DIR/manifest.tsv"
  for ((i=${#TX_TOOLS[@]}-1; i>=0; i--)); do
    case "${TX_STATUS[$i]}" in restored|rolled-back) continue ;; esac
    destination=${TX_DESTS[$i]}; backup=${TX_BACKUPS[$i]}
    printf 'Restore %s\n' "$destination"
    $DRY_RUN && continue
    if [ "${TX_STATUS[$i]}" = intent ] && [ "${TX_EXISTED[$i]}" = yes ] && entry_exists "$destination"; then
      TX_STATUS[$i]=restored
      write_journal || return 1
      continue
    fi
    if [ "${TX_EXISTED[$i]}" = yes ] && ! entry_exists "$backup"; then continue; fi
    saved=
    if entry_exists "$destination"; then
      saved=${backup%/*}/replaced-on-restore
      if entry_exists "$saved"; then echo "Restore already has a saved current configuration: $saved" >&2; return 1; fi
      mkdir -p "${saved%/*}" || return 1
      mv -- "$destination" "$saved" || return 1
    fi
    if [ "${TX_EXISTED[$i]}" = yes ] && ! mv -- "$backup" "$destination"; then
      if [ -n "$saved" ] && entry_exists "$saved" && ! entry_exists "$destination"; then mv -- "$saved" "$destination" || true; fi
      return 1
    fi
    TX_STATUS[$i]=restored
    write_journal || return 1
  done
}
