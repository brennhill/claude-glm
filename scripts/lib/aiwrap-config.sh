#!/usr/bin/env bash

AIWRAP_PLACEHOLDER_AUTH_TOKEN="your-provider-key"
AIWRAP_CONFIG_ROOT="${HOME}/.aiwrap/providers"

aiwrap_die() {
  printf 'aiwrap: %s\n' "$1" >&2
  exit 1
}

aiwrap_provider_config_file() {
  printf '%s/%s.json' "$AIWRAP_CONFIG_ROOT" "$1"
}

aiwrap_json_string() {
  local file=$1
  local path=$2
  jq -er "$path // empty" "$file" 2>/dev/null || true
}

aiwrap_load_provider_config() {
  local provider=$1
  local file
  file=$(aiwrap_provider_config_file "$provider")

  provider_config_file=$file
  provider_config_base_url=""
  provider_config_auth_token=""
  provider_config_default_model=""
  provider_config_haiku_model=""
  provider_config_sonnet_model=""
  provider_config_opus_model=""

  [[ -f "$file" ]] || return 1
  jq empty "$file" >/dev/null 2>&1 || aiwrap_die "Malformed provider config at $file"

  provider_config_base_url=$(aiwrap_json_string "$file" '.base_url')
  provider_config_auth_token=$(aiwrap_json_string "$file" '.auth_token')
  provider_config_default_model=$(aiwrap_json_string "$file" '.models.default')
  provider_config_haiku_model=$(aiwrap_json_string "$file" '.models.haiku')
  provider_config_sonnet_model=$(aiwrap_json_string "$file" '.models.sonnet')
  provider_config_opus_model=$(aiwrap_json_string "$file" '.models.opus')
}

aiwrap_has_usable_token() {
  local token=${1-}
  [[ -n "$token" && "$token" != "$AIWRAP_PLACEHOLDER_AUTH_TOKEN" && "$token" != "your-zai-api-key" ]]
}

aiwrap_json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

aiwrap_is_interactive() {
  [[ -t 0 && -t 2 ]]
}

aiwrap_prompt_for_token() {
  local token
  aiwrap_is_interactive || aiwrap_die "Provider auth token is required. Run scripts/setup.sh or set the provider config explicitly."
  printf 'Enter your Z.ai API key: ' >&2
  IFS= read -r -s token
  printf '\n' >&2
  [[ -n "$token" ]] || aiwrap_die "A non-empty provider API key is required."
  printf '%s' "$token"
}

aiwrap_write_provider_config() {
  local provider=$1
  local auth_token=$2
  local file tmp_file base_url haiku_model sonnet_model opus_model default_model
  file=$(aiwrap_provider_config_file "$provider")
  mkdir -p "$(dirname "$file")"
  tmp_file=$(mktemp)

  base_url=${provider_config_base_url:-$provider_default_base_url}
  haiku_model=${provider_config_haiku_model:-$provider_default_haiku_model}
  sonnet_model=${provider_config_sonnet_model:-$provider_default_sonnet_model}
  opus_model=${provider_config_opus_model:-$provider_default_opus_model}
  default_model=${provider_config_default_model:-$provider_default_default_model}

  if [[ -f "$file" ]]; then
    jq --arg token "$auth_token" '.auth_token = $token' "$file" >"$tmp_file" \
      || { rm -f "$tmp_file"; aiwrap_die "Malformed provider config at $file. Refusing to overwrite it automatically."; }
  else
    jq --null-input \
      --arg base_url "$base_url" \
      --arg auth_token "$auth_token" \
      --arg haiku "$haiku_model" \
      --arg sonnet "$sonnet_model" \
      --arg opus "$opus_model" \
      --arg default_model "$default_model" \
      '{
        base_url: $base_url,
        auth_token: $auth_token,
        models: (
          {haiku: $haiku, sonnet: $sonnet, opus: $opus}
          + (if $default_model == "" then {} else {default: $default_model} end)
        )
      }' >"$tmp_file"
  fi

  mv "$tmp_file" "$file"
  chmod 600 "$file"
}

aiwrap_require_binary() {
  local binary_name=$1
  local resolved
  resolved=$(command -v "$binary_name" || true)
  [[ -n "$resolved" ]] || aiwrap_die "Required binary '$binary_name' was not found in PATH."
  printf '%s' "$resolved"
}
