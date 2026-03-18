#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SWITCHBOARD="$ROOT_DIR/bin/switchboard"

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
set -euo pipefail
printf 'TOOL=claude\n'
printf 'PWD=%s\n' "$PWD"
printf 'BASE_URL=%s\n' "${ANTHROPIC_BASE_URL:-}"
printf 'AUTH=%s\n' "${ANTHROPIC_AUTH_TOKEN:-}"
printf 'HAIKU=%s\n' "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"
printf 'SONNET=%s\n' "${ANTHROPIC_DEFAULT_SONNET_MODEL:-}"
printf 'OPUS=%s\n' "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}"
printf 'ARGS=%s\n' "$*"
EOF
  chmod +x "$stub_dir/claude"
}

make_stub_codex() {
  local stub_dir=$1
  mkdir -p "$stub_dir"
  cat >"$stub_dir/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'TOOL=codex\n'
printf 'PWD=%s\n' "$PWD"
printf 'BASE_URL=%s\n' "${OPENAI_BASE_URL:-}"
printf 'AUTH=%s\n' "${OPENAI_API_KEY:-}"
printf 'MODEL=%s\n' "${OPENAI_MODEL:-}"
printf 'ARGS=%s\n' "$*"
EOF
  chmod +x "$stub_dir/codex"
}

write_provider_config() {
  local home_dir=$1
  local provider=$2
  local payload=$3
  mkdir -p "$home_dir/.aiswitchboard/providers"
  printf '%s\n' "$payload" >"$home_dir/.aiswitchboard/providers/$provider.json"
}

test_switchboard_dispatches_claude_glm() {
  local temp_dir home_dir stub_dir output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"

  write_provider_config "$home_dir" "glm" '{
    "base_url": "https://example.invalid/glm",
    "auth_token": "glm-token",
    "models": {
      "haiku": "glm-haiku",
      "sonnet": "glm-sonnet",
      "opus": "glm-opus"
    }
  }'

  output=$(HOME="$home_dir" PATH="$stub_dir:/usr/bin:/bin" "$SWITCHBOARD" claude glm --print hello 2>&1)

  assert_contains "$output" 'TOOL=claude'
  assert_contains "$output" 'BASE_URL=https://example.invalid/glm'
  assert_contains "$output" 'AUTH=glm-token'
  assert_contains "$output" 'HAIKU=glm-haiku'
  assert_contains "$output" 'SONNET=glm-sonnet'
  assert_contains "$output" 'OPUS=glm-opus'
  assert_contains "$output" 'ARGS=--print hello'
}

test_switchboard_dispatches_codex_claude() {
  local temp_dir home_dir stub_dir output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_codex "$stub_dir"

  write_provider_config "$home_dir" "claude" '{
    "base_url": "https://example.invalid/claude",
    "auth_token": "claude-token",
    "models": {
      "default": "claude-opus-like"
    }
  }'

  output=$(HOME="$home_dir" PATH="$stub_dir:/usr/bin:/bin" "$SWITCHBOARD" codex claude exec hello 2>&1)

  assert_contains "$output" 'TOOL=codex'
  assert_contains "$output" 'BASE_URL=https://example.invalid/claude'
  assert_contains "$output" 'AUTH=claude-token'
  assert_contains "$output" 'MODEL=claude-opus-like'
  assert_contains "$output" 'ARGS=exec hello'
}

test_switchboard_rejects_unknown_tool() {
  local temp_dir home_dir output status
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  mkdir -p "$home_dir"

  set +e
  output=$(HOME="$home_dir" "$SWITCHBOARD" missing glm 2>&1)
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected unknown tool to fail"
  assert_contains "$output" 'Unsupported tool'
}

test_switchboard_rejects_unknown_provider() {
  local temp_dir home_dir output status
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  mkdir -p "$home_dir"

  set +e
  output=$(HOME="$home_dir" "$SWITCHBOARD" claude missing 2>&1)
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected unknown provider to fail"
  assert_contains "$output" 'Unsupported provider'
}

test_switchboard_rejects_unsupported_pair() {
  local temp_dir home_dir stub_dir output status
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_codex "$stub_dir"

  write_provider_config "$home_dir" "glm" '{
    "base_url": "https://example.invalid/glm",
    "auth_token": "glm-token"
  }'

  set +e
  output=$(HOME="$home_dir" PATH="$stub_dir:/usr/bin:/bin" "$SWITCHBOARD" codex glm 2>&1)
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected unsupported pair to fail"
  assert_contains "$output" 'Unsupported tool/provider pair'
}

test_switchboard_forwards_args_to_selected_tool() {
  local temp_dir home_dir stub_dir output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"

  write_provider_config "$home_dir" "glm" '{
    "base_url": "https://example.invalid/glm",
    "auth_token": "glm-token"
  }'

  output=$(HOME="$home_dir" PATH="$stub_dir:/usr/bin:/bin" "$SWITCHBOARD" claude glm --model sonnet prompt text 2>&1)
  assert_contains "$output" 'ARGS=--model sonnet prompt text'
}

test_switchboard_preserves_current_working_directory() {
  local temp_dir home_dir stub_dir work_dir output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  work_dir="$temp_dir/work"
  mkdir -p "$home_dir" "$work_dir"
  make_stub_claude "$stub_dir"

  write_provider_config "$home_dir" "glm" '{
    "base_url": "https://example.invalid/glm",
    "auth_token": "glm-token"
  }'

  output=$(cd "$work_dir" && HOME="$home_dir" PATH="$stub_dir:/usr/bin:/bin" "$SWITCHBOARD" claude glm --help 2>&1)
  assert_contains "$output" "PWD=$work_dir"
}

test_switchboard_creates_missing_provider_config_interactively() {
  local temp_dir home_dir stub_dir output saved_config
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"

  output=$(expect <<EOF
log_user 1
set timeout 5
spawn env HOME=$home_dir PATH=$stub_dir:/usr/bin:/bin $SWITCHBOARD claude glm --help
expect "Enter your Z.ai API key:"
send "fresh-token\r"
expect eof
EOF
)
  saved_config=$(<"$home_dir/.aiswitchboard/providers/glm.json")

  assert_contains "$output" 'Enter your Z.ai API key'
  assert_contains "$output" 'AUTH=fresh-token'
  assert_contains "$saved_config" '"auth_token": "fresh-token"'
}

test_switchboard_prompts_with_provider_specific_label() {
  local temp_dir home_dir stub_dir output saved_config
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_codex "$stub_dir"

  output=$(expect <<EOF
log_user 1
set timeout 5
spawn env HOME=$home_dir PATH=$stub_dir:/usr/bin:/bin $SWITCHBOARD codex claude exec hi
expect "Enter your Anthropic API key:"
send "anthropic-token\r"
expect eof
EOF
)
  saved_config=$(<"$home_dir/.aiswitchboard/providers/claude.json")

  assert_contains "$output" 'Enter your Anthropic API key'
  assert_contains "$output" 'AUTH=anthropic-token'
  assert_contains "$saved_config" '"auth_token": "anthropic-token"'
}

main() {
  [[ -x "$SWITCHBOARD" ]] || fail "switchboard missing at $SWITCHBOARD"
  test_switchboard_dispatches_claude_glm
  test_switchboard_dispatches_codex_claude
  test_switchboard_rejects_unknown_tool
  test_switchboard_rejects_unknown_provider
  test_switchboard_rejects_unsupported_pair
  test_switchboard_forwards_args_to_selected_tool
  test_switchboard_preserves_current_working_directory
  test_switchboard_creates_missing_provider_config_interactively
  test_switchboard_prompts_with_provider_specific_label
  printf 'PASS: test_switchboard.sh\n'
}

main "$@"
