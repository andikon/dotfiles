#!/usr/bin/env bash
# Bash 3.2+; download this script to a file so the wizard keeps terminal input.
set -eo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
snapshot_dir=
cleanup_bootstrap() {
  if [ -n "$snapshot_dir" ]; then
    case "$snapshot_dir" in "${TMPDIR:-/tmp}"/dotfiles.*) rm -rf -- "$snapshot_dir" ;; esac
  fi
}
trap cleanup_bootstrap EXIT
ref=main
repository=andikon/dotfiles
remote=false
forward=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --ref|--repository)
      [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
      case "$1" in --ref) ref=$2 ;; --repository) repository=$2 ;; esac
      shift 2 ;;
    --remote) remote=true; shift ;;
    *) forward+=("$1"); shift ;;
  esac
done
if $remote || [ ! -f "$script_dir/catalog/tools.tsv" ]; then
  command -v curl >/dev/null 2>&1 || { echo 'curl is needed to download the installer.' >&2; exit 1; }
  command -v tar >/dev/null 2>&1 || { echo 'tar is needed to extract the installer.' >&2; exit 1; }
  case "$repository" in *[!A-Za-z0-9_./-]*|*..*|/*|*/|*/*/*) echo 'Invalid repository name.' >&2; exit 2 ;; esac
  case "$repository" in */*) ;; *) echo 'Use owner/repository.' >&2; exit 2 ;; esac
  case "$ref" in ''|*[!A-Za-z0-9_./-]*|*..*) echo 'Invalid revision. Use a tag, branch or commit.' >&2; exit 2 ;; esac
  snapshot_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles.XXXXXXXX")
  # GitHub can return the immutable commit directly without a JSON parser.
  ref_url=${ref//\//%2F}
  curl -fLsS --proto '=https' --tlsv1.2 -H 'Accept: application/vnd.github.sha' \
    "https://api.github.com/repos/$repository/commits/$ref_url" -o "$snapshot_dir/revision"
  revision=$(tr -d '\r\n' < "$snapshot_dir/revision")
  case "$revision" in ''|*[!a-f0-9]*) echo 'GitHub did not return a commit SHA.' >&2; exit 1 ;; esac
  [ "${#revision}" -eq 40 ] || { echo 'GitHub did not return an immutable revision.' >&2; exit 1; }
  printf 'Downloading %s at %s\n' "$repository" "$revision"
  curl -fLsS --proto '=https' --tlsv1.2 "https://github.com/$repository/archive/$revision.tar.gz" -o "$snapshot_dir/snapshot.tar.gz"
  mkdir "$snapshot_dir/repo"
  tar -xzf "$snapshot_dir/snapshot.tar.gz" -C "$snapshot_dir/repo" --strip-components=1
  script_dir=$snapshot_dir/repo
fi
# Run in a child: the bootstrap retains ownership of its temporary snapshot.
"${BASH:-bash}" "$script_dir/installer/bash/installer.sh" --root "$script_dir" "${forward[@]}"
