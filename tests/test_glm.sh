#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WRAPPER="$ROOT_DIR/bin/glm"

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

assert_not_contains() {
  local haystack=$1
  local needle=$2
  if [[ "$haystack" == *"$needle"* ]]; then
    fail "expected output to exclude: $needle"$'\n'"actual: $haystack"
  fi
}

make_stub_claude() {
  local stub_dir=$1
  mkdir -p "$stub_dir"
  cat >"$stub_dir/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'BASE_URL=%s\n' "${ANTHROPIC_BASE_URL:-}"
printf 'AUTH=%s\n' "${ANTHROPIC_AUTH_TOKEN:-}"
printf 'HAIKU=%s\n' "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"
printf 'SONNET=%s\n' "${ANTHROPIC_DEFAULT_SONNET_MODEL:-}"
printf 'OPUS=%s\n' "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}"
printf 'ARGS=%s\n' "$*"
EOF
  chmod +x "$stub_dir/claude"
}

run_wrapper_env() {
  local home_dir=$1
  shift
  HOME="$home_dir" "$WRAPPER" env "$@"
}

run_wrapper_exec() {
  local home_dir=$1
  local path_dir=$2
  shift 2
  HOME="$home_dir" PATH="$path_dir:$PATH" "$WRAPPER" "$@"
}

run_wrapper_interactive() {
  local home_dir=$1
  local path_dir=$2
  local input=$3
  shift 3
  local safe_path
  safe_path="$path_dir:/usr/bin:/bin"
  expect <<EOF
log_user 1
set timeout 5
spawn env HOME=$home_dir PATH=$safe_path $WRAPPER {*}[list $@]
expect "Enter your Z.ai API key:"
send "$input\r"
expect eof
EOF
}

test_wrapper_env_output_redacts_token_and_uses_defaults() {
  local temp_dir home_dir output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  mkdir -p "$home_dir"

  output=$(HOME="$home_dir" GLM_AUTH_TOKEN="secret-token" "$WRAPPER" env)

  assert_contains "$output" 'ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic'
  assert_contains "$output" 'ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air'
  assert_contains "$output" 'ANTHROPIC_DEFAULT_SONNET_MODEL=glm-4.7'
  assert_contains "$output" 'ANTHROPIC_DEFAULT_OPUS_MODEL=glm-5'
  assert_contains "$output" 'ANTHROPIC_AUTH_TOKEN=secr...oken'
  assert_not_contains "$output" 'secret-token'
}

test_wrapper_prefers_glm_env_over_config() {
  local temp_dir home_dir stub_dir output
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"

  cat >"$home_dir/.zai.json" <<'EOF'
{
  "base_url": "https://example.invalid/from-config",
  "auth_token": "config-token",
  "models": {
    "haiku": "config-haiku",
    "sonnet": "config-sonnet",
    "opus": "config-opus"
  }
}
EOF

  output=$(HOME="$home_dir" \
    PATH="$stub_dir:$PATH" \
    GLM_BASE_URL="https://example.invalid/from-env" \
    GLM_AUTH_TOKEN="env-token" \
    GLM_DEFAULT_SONNET_MODEL="env-sonnet" \
    "$WRAPPER" --print hello 2>&1)

  assert_contains "$output" 'BASE_URL=https://example.invalid/from-env'
  assert_contains "$output" 'AUTH=env-token'
  assert_contains "$output" 'HAIKU=config-haiku'
  assert_contains "$output" 'SONNET=env-sonnet'
  assert_contains "$output" 'OPUS=config-opus'
  assert_contains "$output" 'ARGS=--print hello'
}

test_wrapper_requires_auth_token() {
  local temp_dir home_dir output status
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  mkdir -p "$home_dir"

  set +e
  output=$(HOME="$home_dir" "$WRAPPER" env 2>&1)
  status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    fail "expected wrapper to fail without auth token"
  fi

  assert_contains "$output" 'GLM auth token is required'
}

test_wrapper_rejects_placeholder_auth_token() {
  local temp_dir home_dir output status
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  mkdir -p "$home_dir"

  cat >"$home_dir/.zai.json" <<'EOF'
{
  "auth_token": "your-zai-api-key"
}
EOF

  set +e
  output=$(HOME="$home_dir" "$WRAPPER" env 2>&1)
  status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    fail "expected wrapper to reject placeholder auth token"
  fi

  assert_contains "$output" 'Run scripts/setup.sh'
}

test_wrapper_does_not_mutate_parent_shell_env() {
  local temp_dir home_dir stub_dir
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"

  unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL || true
  GLM_AUTH_TOKEN="env-token" run_wrapper_exec "$home_dir" "$stub_dir" --help >/dev/null

  [[ -z "${ANTHROPIC_BASE_URL:-}" ]] || fail "ANTHROPIC_BASE_URL leaked into parent shell"
  [[ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]] || fail "ANTHROPIC_AUTH_TOKEN leaked into parent shell"
}

test_wrapper_prompts_interactively_when_token_missing() {
  local temp_dir home_dir stub_dir output saved_config
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"

  output=$(run_wrapper_interactive "$home_dir" "$stub_dir" 'prompt-token' --print hello 2>&1)
  saved_config=$(<"$home_dir/.zai.json")

  assert_contains "$output" 'Enter your Z.ai API key'
  assert_contains "$output" 'AUTH=prompt-token'
  assert_contains "$saved_config" '"auth_token": "prompt-token"'
}

test_wrapper_fails_non_interactively_when_token_missing() {
  local temp_dir home_dir stub_dir output status
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"

  set +e
  output=$(HOME="$home_dir" PATH="$stub_dir:$PATH" "$WRAPPER" --print hello 2>&1)
  status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    fail "expected non-interactive wrapper call to fail without token"
  fi

  assert_contains "$output" 'Run scripts/setup.sh'
}

main() {
  [[ -x "$WRAPPER" ]] || fail "wrapper missing at $WRAPPER"
  test_wrapper_env_output_redacts_token_and_uses_defaults
  test_wrapper_prefers_glm_env_over_config
  test_wrapper_requires_auth_token
  test_wrapper_rejects_placeholder_auth_token
  test_wrapper_does_not_mutate_parent_shell_env
  test_wrapper_prompts_interactively_when_token_missing
  test_wrapper_fails_non_interactively_when_token_missing
  printf 'PASS: test_glm.sh\n'
}

main "$@"
