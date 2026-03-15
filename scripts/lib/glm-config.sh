#!/usr/bin/env bash

DEFAULT_BASE_URL="https://api.z.ai/api/anthropic"
DEFAULT_HAIKU_MODEL="glm-4.5-air"
DEFAULT_SONNET_MODEL="glm-4.7"
DEFAULT_OPUS_MODEL="glm-5"
PLACEHOLDER_AUTH_TOKEN="your-zai-api-key"

GLM_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GLM_ROOT_DIR=$(cd "$GLM_LIB_DIR/../.." && pwd)
GLM_TEMPLATE_CONFIG="$GLM_ROOT_DIR/templates/zai.json.example"
GLM_CONFIG_FILE="${HOME}/.zai.json"

config_base_url=""
config_auth_token=""
config_haiku_model=""
config_sonnet_model=""
config_opus_model=""

glm_die() {
  printf 'glm: %s\n' "$1" >&2
  exit 1
}

glm_redact_token() {
  local token=${1-}
  local length
  length=${#token}
  if (( length <= 8 )); then
    printf '****'
  else
    printf '%s...%s' "${token:0:4}" "${token:length-4:4}"
  fi
}

glm_json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

glm_has_usable_token() {
  local token=${1-}
  [[ -n "$token" && "$token" != "$PLACEHOLDER_AUTH_TOKEN" ]]
}

glm_is_interactive() {
  [[ -t 0 && -t 2 ]]
}

glm_load_config_with_jq() {
  config_base_url=$(jq -er '.base_url // empty' "$GLM_CONFIG_FILE" 2>/dev/null || true)
  config_auth_token=$(jq -er '.auth_token // empty' "$GLM_CONFIG_FILE" 2>/dev/null || true)
  config_haiku_model=$(jq -er '.models.haiku // empty' "$GLM_CONFIG_FILE" 2>/dev/null || true)
  config_sonnet_model=$(jq -er '.models.sonnet // empty' "$GLM_CONFIG_FILE" 2>/dev/null || true)
  config_opus_model=$(jq -er '.models.opus // empty' "$GLM_CONFIG_FILE" 2>/dev/null || true)
}

glm_load_config_with_fallback() {
  local compact
  compact=$(tr -d '\n\r\t ' <"$GLM_CONFIG_FILE")
  [[ $compact == \{* ]] || glm_die "Malformed config at $GLM_CONFIG_FILE. See templates/zai.json.example."

  glm_extract_json_string() {
    local source=$1
    local key=$2
    local remainder value
    remainder=${source#*\"$key\":\"}
    [[ "$remainder" != "$source" ]] || return 1
    value=${remainder%%\"*}
    printf '%s' "$value"
  }

  local models_section
  config_base_url=$(glm_extract_json_string "$compact" "base_url" || true)
  config_auth_token=$(glm_extract_json_string "$compact" "auth_token" || true)
  models_section=${compact#*\"models\":\{}
  if [[ "$models_section" != "$compact" ]]; then
    config_haiku_model=$(glm_extract_json_string "$models_section" "haiku" || true)
    config_sonnet_model=$(glm_extract_json_string "$models_section" "sonnet" || true)
    config_opus_model=$(glm_extract_json_string "$models_section" "opus" || true)
  fi
}

glm_load_config() {
  config_base_url=""
  config_auth_token=""
  config_haiku_model=""
  config_sonnet_model=""
  config_opus_model=""

  [[ -f "$GLM_CONFIG_FILE" ]] || return 0

  if command -v jq >/dev/null 2>&1; then
    jq empty "$GLM_CONFIG_FILE" >/dev/null 2>&1 || glm_die "Malformed config at $GLM_CONFIG_FILE. See templates/zai.json.example."
    glm_load_config_with_jq
  else
    glm_load_config_with_fallback
  fi
}

glm_resolve_value() {
  local env_name=$1
  local config_value=$2
  local default_value=$3
  local env_value=${!env_name-}

  if [[ -n "$env_value" ]]; then
    printf '%s' "$env_value"
  elif [[ -n "$config_value" ]]; then
    printf '%s' "$config_value"
  else
    printf '%s' "$default_value"
  fi
}

glm_write_config() {
  local auth_token=$1
  local base_url haiku_model sonnet_model opus_model tmp_file
  base_url=${config_base_url:-$DEFAULT_BASE_URL}
  haiku_model=${config_haiku_model:-$DEFAULT_HAIKU_MODEL}
  sonnet_model=${config_sonnet_model:-$DEFAULT_SONNET_MODEL}
  opus_model=${config_opus_model:-$DEFAULT_OPUS_MODEL}
  tmp_file=$(mktemp)

  if command -v jq >/dev/null 2>&1; then
    if [[ -f "$GLM_CONFIG_FILE" ]]; then
      jq --arg token "$auth_token" '.auth_token = $token' "$GLM_CONFIG_FILE" >"$tmp_file" \
        || { rm -f "$tmp_file"; glm_die "Malformed config at $GLM_CONFIG_FILE. Refusing to overwrite it automatically."; }
    else
      jq --null-input \
        --arg base_url "$base_url" \
        --arg auth_token "$auth_token" \
        --arg haiku "$haiku_model" \
        --arg sonnet "$sonnet_model" \
        --arg opus "$opus_model" \
        '{base_url: $base_url, auth_token: $auth_token, models: {haiku: $haiku, sonnet: $sonnet, opus: $opus}}' >"$tmp_file"
    fi
  else
    cat >"$tmp_file" <<EOF
{
  "base_url": "$(glm_json_escape "$base_url")",
  "auth_token": "$(glm_json_escape "$auth_token")",
  "models": {
    "haiku": "$(glm_json_escape "$haiku_model")",
    "sonnet": "$(glm_json_escape "$sonnet_model")",
    "opus": "$(glm_json_escape "$opus_model")"
  }
}
EOF
  fi

  mv "$tmp_file" "$GLM_CONFIG_FILE"
  chmod 600 "$GLM_CONFIG_FILE"
}

glm_prompt_for_token() {
  local token
  glm_is_interactive || glm_die "GLM auth token is required. Run scripts/setup.sh or set GLM_AUTH_TOKEN."
  printf 'Enter your Z.ai API key: ' >&2
  IFS= read -r -s token
  printf '\n' >&2
  [[ -n "$token" ]] || glm_die "A non-empty Z.ai API key is required."
  printf '%s' "$token"
}

glm_require_claude() {
  local claude_bin
  claude_bin=$(command -v claude || true)
  [[ -n "$claude_bin" ]] || glm_die "Claude Code CLI not found in PATH. Install it before using glm."
  printf '%s' "$claude_bin"
}
