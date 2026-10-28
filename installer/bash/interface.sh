print_status() {
  local index=$1 label=$2 prefix=${3:-} color=$RED
  if [ "${STATUS_READY[$index]}" = true ]; then color=$GREEN; fi
  printf '%s%s%-27s %-15s %s%s\n' "$color" "$prefix" "$label" "${STATUS_TEXT[$index]}" "${STATUS_DETAILS[$index]}" "$RESET"
}

read_answer() {
  printf '%s' "$1"
  if ! IFS= read -r ANSWER; then echo 'Input ended; cancelled.' >&2; return 1; fi
}

select_items() {
  local title=$1 i key rest cursor=0 start height row index mark arrow token valid line rows=24 columns=80
  local picked=() tokens=()
  SELECTED=()
  [ "${#MENU_IDS[@]}" -gt 0 ] || return 0
  printf '\n%s%s%s\n' "$CYAN" "$title" "$RESET"
  for ((i=0; i<${#MENU_IDS[@]}; i++)); do picked+=("${MENU_DEFAULTS[$i]}"); done
  if [ "${DOTFILES_NO_TUI:-}" != 1 ] && [ -t 0 ] && [ -t 1 ] && [ "${TERM:-dumb}" != dumb ]; then
    if command -v stty >/dev/null 2>&1; then read -r rows columns < <(stty size) || { rows=24; columns=80; }; fi
    [ "$rows" -gt 4 ] || rows=24
    [ "$columns" -gt 10 ] || columns=80
    height=${#MENU_IDS[@]}; [ "$height" -le 10 ] || height=10
    [ "$height" -le "$((rows-3))" ] || height=$((rows-3))
    echo 'Arrows: move | Space: select | A: all | Enter: continue | Esc: cancel'
    for ((i=0; i<height; i++)); do printf '\n'; done
    while :; do
      printf '\033[%sA' "$height"
      start=$((cursor-height+1)); [ "$start" -ge 0 ] || start=0
      for ((row=0; row<height; row++)); do
        index=$((start+row)); mark=' '; arrow=' '
        [ "${picked[$index]}" != true ] || mark=x
        [ "$index" -ne "$cursor" ] || arrow='>'
        line="$arrow [$mark] ${MENU_LABELS[$index]}"
        printf '\r\033[2K%.*s\n' "$((columns-1))" "$line"
      done
      IFS= read -r -s -n 1 key || return 1
      case "$key" in
        '') break ;;
        ' ') if [ "${picked[$cursor]}" = true ]; then picked[$cursor]=false; else picked[$cursor]=true; fi ;;
        a|A)
          valid=false
          for token in "${picked[@]}"; do [ "$token" != false ] || valid=true; done
          for ((i=0; i<${#picked[@]}; i++)); do picked[$i]=$valid; done ;;
        $'\033')
          rest=
          if IFS= read -r -s -n 1 -t 1 rest && [ "$rest" = '[' ]; then
            IFS= read -r -s -n 1 -t 1 rest || return 1
            case "$rest" in A) [ "$cursor" -le 0 ] || cursor=$((cursor-1)) ;; B) [ "$cursor" -ge "$((${#MENU_IDS[@]}-1))" ] || cursor=$((cursor+1)) ;; esac
          else echo 'Cancelled.'; return 1
          fi ;;
      esac
    done
    for ((i=0; i<${#picked[@]}; i++)); do if [ "${picked[$i]}" = true ]; then SELECTED+=("${MENU_IDS[$i]}"); fi; done
    return 0
  fi
  for ((i=0; i<${#MENU_IDS[@]}; i++)); do
    mark=' '; [ "${picked[$i]}" != true ] || mark=x
    printf '%2d. [%s] %s\n' "$((i+1))" "$mark" "${MENU_LABELS[$i]}"
  done
  while :; do
    read_answer 'Numbers separated by commas; Enter keeps defaults; all, none, or cancel: ' || return 1
    case "$ANSWER" in
      cancel) echo 'Cancelled.'; return 1 ;;
      all) SELECTED=("${MENU_IDS[@]}"); return 0 ;;
      none) return 0 ;;
      '') for ((i=0; i<${#picked[@]}; i++)); do if [ "${picked[$i]}" = true ]; then SELECTED+=("${MENU_IDS[$i]}"); fi; done; return 0 ;;
    esac
    IFS=, read -r -a tokens <<< "$ANSWER"
    valid=true
    for ((i=0; i<${#tokens[@]}; i++)); do
      token=${tokens[$i]// /}; tokens[$i]=$token
      case "$token" in ''|*[!0-9]*) valid=false ;; *) if [ "$token" -lt 1 ] || [ "$token" -gt "${#MENU_IDS[@]}" ]; then valid=false; fi ;; esac
    done
    if ! $valid; then echo 'Choose one of the displayed numbers.'; continue; fi
    # Iterate the menu to deduplicate selections and retain catalog order.
    for ((i=0; i<${#MENU_IDS[@]}; i++)); do
      for token in "${tokens[@]}"; do
        if [ "$((10#$token))" -eq "$((i+1))" ]; then SELECTED+=("${MENU_IDS[$i]}"); break; fi
      done
    done
    return 0
  done
}
