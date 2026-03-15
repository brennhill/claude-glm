#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SETUP_SCRIPT="$ROOT_DIR/scripts/setup.sh"

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

make_stub_claude() {
  local stub_dir=$1
  mkdir -p "$stub_dir"
  cat >"$stub_dir/claude" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$stub_dir/claude"
}

provider_config_path() {
  local home_dir=$1
  local provider=$2
  printf '%s/.aiwrap/providers/%s.json' "$home_dir" "$provider"
}

run_setup_interactive() {
  local home_dir=$1
  local path_dir=$2
  local input=$3
  local extra_args=${4-}
  local safe_path
  safe_path="$path_dir:/usr/bin:/bin"
  expect <<EOF
log_user 1
set timeout 5
spawn env HOME=$home_dir PATH=$safe_path $SETUP_SCRIPT {*}[list $extra_args]
expect "Enter your Z.ai API key:"
send "$input\r"
expect eof
EOF
}

test_setup_prompts_for_token_and_writes_glm_provider_config() {
  local temp_dir home_dir stub_dir output saved_config config_file
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"
  config_file=$(provider_config_path "$home_dir" "glm")

  output=$(run_setup_interactive "$home_dir" "$stub_dir" 'setup-token' 2>&1)
  saved_config=$(<"$config_file")

  assert_contains "$output" 'Enter your Z.ai API key'
  assert_contains "$output" 'aiwrap installation complete'
  assert_contains "$saved_config" '"auth_token": "setup-token"'
}

test_setup_preserves_existing_non_token_config() {
  local temp_dir home_dir stub_dir output saved_config config_file
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"
  config_file=$(provider_config_path "$home_dir" "glm")

  mkdir -p "$(dirname "$config_file")"
  cat >"$config_file" <<'EOF'
{
  "base_url": "https://example.invalid/custom",
  "auth_token": "your-zai-api-key",
  "models": {
    "haiku": "keep-haiku",
    "sonnet": "keep-sonnet",
    "opus": "keep-opus"
  }
}
EOF

  output=$(run_setup_interactive "$home_dir" "$stub_dir" 'updated-token' 2>&1)
  saved_config=$(<"$config_file")

  assert_contains "$output" 'Saved token'
  assert_contains "$saved_config" '"base_url": "https://example.invalid/custom"'
  assert_contains "$saved_config" '"haiku": "keep-haiku"'
  assert_contains "$saved_config" '"sonnet": "keep-sonnet"'
  assert_contains "$saved_config" '"opus": "keep-opus"'
  assert_contains "$saved_config" '"auth_token": "updated-token"'
}

test_setup_mentions_reset_flag_when_token_exists() {
  local temp_dir home_dir stub_dir output saved_config config_file
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"
  config_file=$(provider_config_path "$home_dir" "glm")

  mkdir -p "$(dirname "$config_file")"
  cat >"$config_file" <<'EOF'
{
  "auth_token": "existing-token"
}
EOF

  output=$(HOME="$home_dir" PATH="$stub_dir:/usr/bin:/bin" "$SETUP_SCRIPT")
  saved_config=$(<"$config_file")

  assert_contains "$output" 'Using existing token'
  assert_contains "$output" '--reset-token'
  assert_contains "$saved_config" '"auth_token": "existing-token"'
}

test_setup_reset_token_updates_existing_key() {
  local temp_dir home_dir stub_dir output saved_config config_file
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"
  config_file=$(provider_config_path "$home_dir" "glm")

  mkdir -p "$(dirname "$config_file")"
  cat >"$config_file" <<'EOF'
{
  "base_url": "https://example.invalid/custom",
  "auth_token": "existing-token",
  "models": {
    "haiku": "keep-haiku",
    "sonnet": "keep-sonnet",
    "opus": "keep-opus"
  }
}
EOF

  output=$(run_setup_interactive "$home_dir" "$stub_dir" 'rotated-token' '--reset-token' 2>&1)
  saved_config=$(<"$config_file")

  assert_contains "$output" 'Enter your Z.ai API key'
  assert_contains "$output" 'Saved token'
  assert_contains "$saved_config" '"base_url": "https://example.invalid/custom"'
  assert_contains "$saved_config" '"auth_token": "rotated-token"'
}

test_setup_accepts_provider_argument() {
  local temp_dir home_dir stub_dir output saved_config config_file
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"
  config_file=$(provider_config_path "$home_dir" "claude")

  output=$(run_setup_interactive "$home_dir" "$stub_dir" 'claude-provider-token' 'claude' 2>&1)
  saved_config=$(<"$config_file")

  assert_contains "$output" 'Saved token'
  assert_contains "$saved_config" '"auth_token": "claude-provider-token"'
}

test_setup_uses_provider_specific_prompt_label() {
  local temp_dir home_dir stub_dir output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"

  output=$(expect <<EOF
log_user 1
set timeout 5
spawn env HOME=$home_dir PATH=$stub_dir:/usr/bin:/bin $SETUP_SCRIPT claude
expect "Enter your Anthropic API key:"
send "claude-setup-token\r"
expect eof
EOF
)

  assert_contains "$output" 'Enter your Anthropic API key'
}

test_setup_defaults_to_glm_provider() {
  local temp_dir home_dir stub_dir output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"

  output=$(run_setup_interactive "$home_dir" "$stub_dir" 'default-token' 2>&1)
  [[ -f "$(provider_config_path "$home_dir" "glm")" ]] || fail "expected default glm provider config to be created"
  assert_contains "$output" 'Saved token'
}

test_setup_fails_noninteractively_without_token() {
  local temp_dir home_dir stub_dir output status
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"

  set +e
  output=$(HOME="$home_dir" PATH="$stub_dir:/usr/bin:/bin" "$SETUP_SCRIPT" claude 2>&1)
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected non-interactive setup to fail without token"
  assert_contains "$output" 'auth token is required'
}

test_setup_does_not_require_claude_binary() {
  local temp_dir home_dir output saved_config
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  mkdir -p "$home_dir"

  output=$(run_setup_interactive "$home_dir" "/usr/bin:/bin" 'no-claude-token' 2>&1)
  saved_config=$(<"$(provider_config_path "$home_dir" "glm")")

  assert_contains "$output" 'Saved token'
  assert_contains "$saved_config" '"auth_token": "no-claude-token"'
}

main() {
  [[ -x "$SETUP_SCRIPT" ]] || fail "setup script missing at $SETUP_SCRIPT"
  test_setup_prompts_for_token_and_writes_glm_provider_config
  test_setup_preserves_existing_non_token_config
  test_setup_mentions_reset_flag_when_token_exists
  test_setup_reset_token_updates_existing_key
  test_setup_accepts_provider_argument
  test_setup_uses_provider_specific_prompt_label
  test_setup_defaults_to_glm_provider
  test_setup_fails_noninteractively_without_token
  test_setup_does_not_require_claude_binary
  printf 'PASS: test_setup.sh\n'
}

main "$@"
