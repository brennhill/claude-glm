#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
BIN_DIR="$ROOT_DIR/bin"
TEMPLATE_CONFIG="$ROOT_DIR/templates/zai.json.example"
TARGET_CONFIG="${HOME}/.zai.json"
START_MARKER='# >>> glm wrapper >>>'
END_MARKER='# <<< glm wrapper <<<'

ensure_rc_block() {
  local rc_file=$1
  local temp_file
  local block

  mkdir -p "$(dirname "$rc_file")"
  touch "$rc_file"

  temp_file=$(mktemp)
  awk -v start="$START_MARKER" -v end="$END_MARKER" '
    $0 == start { in_block=1; next }
    $0 == end { in_block=0; next }
    !in_block { print }
  ' "$rc_file" >"$temp_file"
  mv "$temp_file" "$rc_file"

  block=$(
    cat <<EOF
$START_MARKER
export PATH="$BIN_DIR:\$PATH"
$END_MARKER
EOF
  )

  if [[ -s "$rc_file" ]]; then
    printf '\n%s\n' "$block" >>"$rc_file"
  else
    printf '%s\n' "$block" >"$rc_file"
  fi

  printf 'Updated %s\n' "$rc_file"
}

install_config() {
  if [[ -f "$TARGET_CONFIG" ]]; then
    chmod 600 "$TARGET_CONFIG"
    printf 'Using existing %s\n' "$TARGET_CONFIG"
    return 0
  fi

  cp "$TEMPLATE_CONFIG" "$TARGET_CONFIG"
  chmod 600 "$TARGET_CONFIG"
  printf 'Created %s\n' "$TARGET_CONFIG"
  printf 'Set your real Z.ai API key in %s before using glm.\n' "$TARGET_CONFIG"
}

install_main() {
  [[ -x "$BIN_DIR/glm" ]] || printf 'Warning: %s is not executable yet.\n' "$BIN_DIR/glm" >&2

  ensure_rc_block "${HOME}/.zshrc"
  ensure_rc_block "${HOME}/.zprofile"
  ensure_rc_block "${HOME}/.bashrc"
  ensure_rc_block "${HOME}/.bash_profile"
  install_config

  printf 'glm installation complete. Restart your shell or source your rc file.\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  install_main "$@"
fi
