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

make_stub_claude() {
  local stub_dir=$1
  mkdir -p "$stub_dir"
  cat >"$stub_dir/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'TOOL=claude\n'
printf 'BASE_URL=%s\n' "${ANTHROPIC_BASE_URL:-}"
printf 'AUTH=%s\n' "${ANTHROPIC_AUTH_TOKEN:-}"
printf 'HAIKU=%s\n' "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"
printf 'SONNET=%s\n' "${ANTHROPIC_DEFAULT_SONNET_MODEL:-}"
printf 'OPUS=%s\n' "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}"
printf 'ARGS=%s\n' "$*"
EOF
  chmod +x "$stub_dir/claude"
}

provider_config_path() {
  local home_dir=$1
  printf '%s/.aiwrap/providers/glm.json' "$home_dir"
}

run_glm_function() {
  local home_dir=$1
  local path_dir=$2
  shift 2
  HOME="$home_dir" PATH="$path_dir:/usr/bin:/bin" bash -lc 'source "$HOME/.bashrc"; glm "$@"' bash "$@"
}

run_glm_function_interactive() {
  local home_dir=$1
  local path_dir=$2
  local input=$3
  shift 3
  expect <<EOF
log_user 1
set timeout 5
spawn env HOME=$home_dir PATH=$path_dir:/usr/bin:/bin bash -lc {source "$HOME/.bashrc"; glm {*}[list $@]}
expect "Enter your Z.ai API key:"
send "$input\r"
expect eof
EOF
}

test_glm_function_delegates_to_aiwrap_claude_glm() {
  local temp_dir home_dir stub_dir output config_file
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"
  HOME="$home_dir" "$INSTALLER" >/dev/null
  config_file=$(provider_config_path "$home_dir")
  mkdir -p "$(dirname "$config_file")"

  cat >"$config_file" <<'EOF'
{
  "base_url": "https://example.invalid/glm",
  "auth_token": "glm-token",
  "models": {
    "haiku": "glm-haiku",
    "sonnet": "glm-sonnet",
    "opus": "glm-opus"
  }
}
EOF

  output=$(run_glm_function "$home_dir" "$stub_dir" --print hello 2>&1)

  assert_contains "$output" 'TOOL=claude'
  assert_contains "$output" 'BASE_URL=https://example.invalid/glm'
  assert_contains "$output" 'AUTH=glm-token'
  assert_contains "$output" 'ARGS=--print hello'
}

test_glm_function_does_not_mutate_parent_shell_env() {
  local temp_dir home_dir stub_dir
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"
  HOME="$home_dir" "$INSTALLER" >/dev/null
  mkdir -p "$home_dir/.aiwrap/providers"

  cat >"$home_dir/.aiwrap/providers/glm.json" <<'EOF'
{
  "auth_token": "glm-token"
}
EOF

  unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL || true
  run_glm_function "$home_dir" "$stub_dir" --help >/dev/null

  [[ -z "${ANTHROPIC_BASE_URL:-}" ]] || fail "ANTHROPIC_BASE_URL leaked into parent shell"
  [[ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]] || fail "ANTHROPIC_AUTH_TOKEN leaked into parent shell"
}

test_glm_function_prompts_interactively_when_token_missing() {
  local temp_dir home_dir stub_dir output saved_config
  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  stub_dir="$temp_dir/stub"
  mkdir -p "$home_dir"
  make_stub_claude "$stub_dir"
  HOME="$home_dir" "$INSTALLER" >/dev/null

  output=$(run_glm_function_interactive "$home_dir" "$stub_dir" 'prompt-token' --print hello 2>&1)
  saved_config=$(<"$(provider_config_path "$home_dir")")

  assert_contains "$output" 'Enter your Z.ai API key'
  assert_contains "$output" 'AUTH=prompt-token'
  assert_contains "$saved_config" '"auth_token": "prompt-token"'
}

main() {
  [[ -x "$ROOT_DIR/bin/aiwrap" ]] || fail "aiwrap missing at $ROOT_DIR/bin/aiwrap"
  test_glm_function_delegates_to_aiwrap_claude_glm
  test_glm_function_does_not_mutate_parent_shell_env
  test_glm_function_prompts_interactively_when_token_missing
  printf 'PASS: test_glm.sh\n'
}

main "$@"
