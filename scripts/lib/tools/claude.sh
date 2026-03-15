#!/usr/bin/env bash

tool_claude_binary() {
  command -v claude || true
}

tool_claude_supports_provider() {
  case "$1" in
    glm) return 0 ;;
    *) return 1 ;;
  esac
}

tool_claude_exec() {
  local binary=$1
  shift

  exec env \
    ANTHROPIC_BASE_URL="${provider_config_base_url:-$provider_default_base_url}" \
    ANTHROPIC_AUTH_TOKEN="$provider_config_auth_token" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="${provider_config_haiku_model:-$provider_default_haiku_model}" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="${provider_config_sonnet_model:-$provider_default_sonnet_model}" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="${provider_config_opus_model:-$provider_default_opus_model}" \
    "$binary" "$@"
}
