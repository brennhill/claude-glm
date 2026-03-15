#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INSTALLER="$ROOT_DIR/scripts/install.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local haystack=$1
  local needle=$2
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "expected output to contain: $needle"$'\n'"actual: $haystack"
  fi
}

test_install_updates_shell_files_once() {
  local temp_dir home_dir zshrc zprofile bashrc bash_profile output block_count expected_line
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  zshrc="$home_dir/.zshrc"
  zprofile="$home_dir/.zprofile"
  bashrc="$home_dir/.bashrc"
  bash_profile="$home_dir/.bash_profile"
  mkdir -p "$home_dir"
  : >"$zshrc"
  : >"$zprofile"
  : >"$bashrc"
  : >"$bash_profile"

  HOME="$home_dir" "$INSTALLER" >/dev/null
  HOME="$home_dir" "$INSTALLER" >/dev/null

  expected_line="export PATH=\"$ROOT_DIR/bin:\$PATH\""

  output=$(<"$zshrc")
  assert_contains "$output" '# >>> aiwrap >>>'
  assert_contains "$output" "$expected_line"
  assert_contains "$output" 'glm() { aiwrap claude glm "$@"; }'

  output=$(<"$bashrc")
  assert_contains "$output" '# >>> aiwrap >>>'
  assert_contains "$output" "$expected_line"
  assert_contains "$output" 'glm() { aiwrap claude glm "$@"; }'

  output=$(<"$zprofile")
  assert_contains "$output" '# >>> aiwrap >>>'
  output=$(<"$bash_profile")
  assert_contains "$output" '# >>> aiwrap >>>'

  block_count=$(grep -c '# >>> aiwrap >>>' "$zshrc")
  [[ "$block_count" == "1" ]] || fail "expected one managed block in .zshrc, saw $block_count"
}

test_install_creates_provider_config_with_restricted_permissions() {
  local temp_dir home_dir config_file perm output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  mkdir -p "$home_dir"

  output=$(HOME="$home_dir" "$INSTALLER")
  config_file="$home_dir/.aiwrap/providers/glm.json"

  [[ -f "$config_file" ]] || fail "expected installer to create $config_file"
  assert_contains "$output" 'Created'

  perm=$(stat -f '%Lp' "$config_file")
  [[ "$perm" == "600" ]] || fail "expected provider config permissions 600, saw $perm"
}

test_login_shells_expose_glm_function() {
  local temp_dir home_dir bash_type_output zsh_type_output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  mkdir -p "$home_dir"

  HOME="$home_dir" "$INSTALLER" >/dev/null
  bash_type_output=$(HOME="$home_dir" bash -lc 'type glm' 2>&1)
  zsh_type_output=$(HOME="$home_dir" zsh -lc 'type glm' 2>&1)

  assert_contains "$bash_type_output" 'glm is a function'
  assert_contains "$zsh_type_output" 'glm is a shell function'
}

main() {
  [[ -x "$INSTALLER" ]] || fail "installer missing at $INSTALLER"
  test_install_updates_shell_files_once
  test_install_creates_provider_config_with_restricted_permissions
  test_login_shells_expose_glm_function
  printf 'PASS: test_install.sh\n'
}

main "$@"
