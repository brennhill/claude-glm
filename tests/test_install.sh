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
  assert_contains "$output" '# >>> switchboard >>>'
  assert_contains "$output" "$expected_line"
  assert_contains "$output" 'swb() { switchboard "$@"; }'
  assert_contains "$output" 'glm() { switchboard claude glm "$@"; }'

  output=$(<"$bashrc")
  assert_contains "$output" '# >>> switchboard >>>'
  assert_contains "$output" "$expected_line"
  assert_contains "$output" 'swb() { switchboard "$@"; }'
  assert_contains "$output" 'glm() { switchboard claude glm "$@"; }'

  output=$(<"$zprofile")
  assert_contains "$output" '# >>> switchboard >>>'
  output=$(<"$bash_profile")
  assert_contains "$output" '# >>> switchboard >>>'

  block_count=$(grep -c '# >>> switchboard >>>' "$zshrc")
  [[ "$block_count" == "1" ]] || fail "expected one managed block in .zshrc, saw $block_count"
}

test_install_replaces_legacy_aiwrap_blocks() {
  local temp_dir home_dir zshrc output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  zshrc="$home_dir/.zshrc"
  mkdir -p "$home_dir"

  cat >"$zshrc" <<'EOF'
# >>> aiwrap >>>
export PATH="/old/path:$PATH"
glm() { aiwrap claude glm "$@"; }
# <<< aiwrap <<<
EOF

  HOME="$home_dir" "$INSTALLER" >/dev/null
  output=$(<"$zshrc")

  [[ "$output" != *'# >>> aiwrap >>>'* ]] || fail "expected legacy aiwrap block to be removed"
  assert_contains "$output" '# >>> switchboard >>>'
  assert_contains "$output" 'swb() { switchboard "$@"; }'
  assert_contains "$output" 'glm() { switchboard claude glm "$@"; }'
}

test_install_creates_provider_config_with_restricted_permissions() {
  local temp_dir home_dir config_file perm output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  mkdir -p "$home_dir"

  output=$(HOME="$home_dir" "$INSTALLER")
  config_file="$home_dir/.aiswitchboard/providers/glm.json"

  [[ -f "$config_file" ]] || fail "expected installer to create $config_file"
  assert_contains "$output" 'Created'

  perm=$(stat -f '%Lp' "$config_file")
  [[ "$perm" == "600" ]] || fail "expected provider config permissions 600, saw $perm"
}

test_install_migrates_legacy_provider_config() {
  local temp_dir home_dir legacy_dir config_file output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  legacy_dir="$home_dir/.aiwrap/providers"
  config_file="$home_dir/.aiswitchboard/providers/glm.json"
  mkdir -p "$legacy_dir"

  cat >"$legacy_dir/glm.json" <<'EOF'
{
  "auth_token": "legacy-token"
}
EOF

  output=$(HOME="$home_dir" "$INSTALLER")

  [[ -f "$config_file" ]] || fail "expected installer to create migrated config at $config_file"
  assert_contains "$output" 'Migrated'
  assert_contains "$(<"$config_file")" '"auth_token": "legacy-token"'
}

test_login_shells_expose_switchboard_and_glm_functions() {
  local temp_dir home_dir bash_glm_output zsh_glm_output bash_swb_output zsh_swb_output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  mkdir -p "$home_dir"

  HOME="$home_dir" "$INSTALLER" >/dev/null
  bash_glm_output=$(HOME="$home_dir" bash -lc 'type glm' 2>&1)
  zsh_glm_output=$(HOME="$home_dir" zsh -lc 'type glm' 2>&1)
  bash_swb_output=$(HOME="$home_dir" bash -lc 'type swb' 2>&1)
  zsh_swb_output=$(HOME="$home_dir" zsh -lc 'type swb' 2>&1)

  assert_contains "$bash_glm_output" 'glm is a function'
  assert_contains "$zsh_glm_output" 'glm is a shell function'
  assert_contains "$bash_swb_output" 'swb is a function'
  assert_contains "$zsh_swb_output" 'swb is a shell function'
}

main() {
  [[ -x "$INSTALLER" ]] || fail "installer missing at $INSTALLER"
  test_install_updates_shell_files_once
  test_install_replaces_legacy_aiwrap_blocks
  test_install_creates_provider_config_with_restricted_permissions
  test_install_migrates_legacy_provider_config
  test_login_shells_expose_switchboard_and_glm_functions
  printf 'PASS: test_install.sh\n'
}

main "$@"
