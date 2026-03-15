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

test_install_updates_zsh_and_bash_rc_files_once() {
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
  assert_contains "$output" '# >>> glm wrapper >>>'
  assert_contains "$output" "$expected_line"

  output=$(<"$bashrc")
  assert_contains "$output" '# >>> glm wrapper >>>'
  assert_contains "$output" "$expected_line"

  output=$(<"$zprofile")
  assert_contains "$output" '# >>> glm wrapper >>>'
  assert_contains "$output" "$expected_line"

  output=$(<"$bash_profile")
  assert_contains "$output" '# >>> glm wrapper >>>'
  assert_contains "$output" "$expected_line"

  block_count=$(grep -c '# >>> glm wrapper >>>' "$zshrc")
  [[ "$block_count" == "1" ]] || fail "expected one managed block in .zshrc, saw $block_count"

  block_count=$(grep -c '# >>> glm wrapper >>>' "$bashrc")
  [[ "$block_count" == "1" ]] || fail "expected one managed block in .bashrc, saw $block_count"

  block_count=$(grep -c '# >>> glm wrapper >>>' "$zprofile")
  [[ "$block_count" == "1" ]] || fail "expected one managed block in .zprofile, saw $block_count"

  block_count=$(grep -c '# >>> glm wrapper >>>' "$bash_profile")
  [[ "$block_count" == "1" ]] || fail "expected one managed block in .bash_profile, saw $block_count"
}

test_install_creates_example_config_with_restricted_permissions() {
  local temp_dir home_dir config_file perm output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  mkdir -p "$home_dir"

  output=$(HOME="$home_dir" "$INSTALLER")
  config_file="$home_dir/.zai.json"

  [[ -f "$config_file" ]] || fail "expected installer to create $config_file"
  assert_contains "$output" 'Created'

  perm=$(stat -f '%Lp' "$config_file")
  [[ "$perm" == "600" ]] || fail "expected .zai.json permissions 600, saw $perm"
}

main() {
  [[ -x "$INSTALLER" ]] || fail "installer missing at $INSTALLER"
  test_install_updates_zsh_and_bash_rc_files_once
  test_install_creates_example_config_with_restricted_permissions
  printf 'PASS: test_install.sh\n'
}

main "$@"
