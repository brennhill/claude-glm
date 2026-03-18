#!/usr/bin/env bash

SWITCHBOARD_PLACEHOLDER_AUTH_TOKEN="your-provider-key"
SWITCHBOARD_CONFIG_ROOT="${HOME}/.aiswitchboard/providers"

switchboard_die() {
  printf 'switchboard: %s\n' "$1" >&2
  exit 1
}

switchboard_provider_config_file() {
  printf '%s/%s.json' "$SWITCHBOARD_CONFIG_ROOT" "$1"
}

switchboard_json_string() {
  local file=$1
  local path=$2
  jq -er "$path // empty" "$file" 2>/dev/null || true
}

switchboard_load_provider_config() {
  local provider=$1
  local file
  file=$(switchboard_provider_config_file "$provider")

  provider_config_file=$file
  provider_config_base_url=""
  provider_config_auth_token=""
  provider_config_default_model=""
  provider_config_haiku_model=""
  provider_config_sonnet_model=""
  provider_config_opus_model=""

  [[ -f "$file" ]] || return 1
  jq empty "$file" >/dev/null 2>&1 || switchboard_die "Malformed provider config at $file"

  provider_config_base_url=$(switchboard_json_string "$file" '.base_url')
  provider_config_auth_token=$(switchboard_json_string "$file" '.auth_token')
  provider_config_default_model=$(switchboard_json_string "$file" '.models.default')
  provider_config_haiku_model=$(switchboard_json_string "$file" '.models.haiku')
  provider_config_sonnet_model=$(switchboard_json_string "$file" '.models.sonnet')
  provider_config_opus_model=$(switchboard_json_string "$file" '.models.opus')
}

switchboard_has_usable_token() {
  local token=${1-}
  [[ -n "$token" && "$token" != "$SWITCHBOARD_PLACEHOLDER_AUTH_TOKEN" && "$token" != "your-zai-api-key" ]]
}

switchboard_json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

switchboard_is_interactive() {
  [[ -t 0 && -t 2 ]]
}

switchboard_prompt_for_token() {
  local token
  switchboard_is_interactive || switchboard_die "Provider auth token is required. Run scripts/setup.sh or set the provider config explicitly."
  printf 'Enter your %s API key: ' "${provider_default_auth_label:-provider}" >&2
  IFS= read -r -s token
  printf '\n' >&2
  [[ -n "$token" ]] || switchboard_die "A non-empty provider API key is required."
  printf '%s' "$token"
}

switchboard_write_provider_config() {
  local provider=$1
  local auth_token=$2
  local file tmp_file base_url haiku_model sonnet_model opus_model default_model
  file=$(switchboard_provider_config_file "$provider")
  mkdir -p "$(dirname "$file")"
  tmp_file=$(mktemp)

  base_url=${provider_config_base_url:-$provider_default_base_url}
  haiku_model=${provider_config_haiku_model:-$provider_default_haiku_model}
  sonnet_model=${provider_config_sonnet_model:-$provider_default_sonnet_model}
  opus_model=${provider_config_opus_model:-$provider_default_opus_model}
  default_model=${provider_config_default_model:-$provider_default_default_model}

  if [[ -f "$file" ]]; then
    jq --arg token "$auth_token" '.auth_token = $token' "$file" >"$tmp_file" \
      || { rm -f "$tmp_file"; switchboard_die "Malformed provider config at $file. Refusing to overwrite it automatically."; }
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

switchboard_require_binary() {
  local binary_name=$1
  local resolved
  resolved=$(command -v "$binary_name" || true)
  [[ -n "$resolved" ]] || switchboard_die "Required binary '$binary_name' was not found in PATH."
  printf '%s' "$resolved"
}
