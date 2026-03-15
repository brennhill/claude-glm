#!/usr/bin/env bash

tool_codex_binary() {
  command -v codex || true
}

tool_codex_supports_provider() {
  case "$1" in
    claude) return 0 ;;
    *) return 1 ;;
  esac
}

tool_codex_exec() {
  local binary=$1
  shift
  local default_model
  default_model=${provider_config_default_model:-${provider_config_opus_model:-$provider_default_default_model}}

  exec env \
    OPENAI_BASE_URL="${provider_config_base_url:-$provider_default_base_url}" \
    OPENAI_API_KEY="$provider_config_auth_token" \
    OPENAI_MODEL="$default_model" \
    "$binary" "$@"
}
