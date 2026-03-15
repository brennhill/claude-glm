#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/install.sh"
source "$SCRIPT_DIR/lib/aiwrap-config.sh"

usage() {
  printf 'Usage: %s [provider] [--reset-token]\n' "$0" >&2
  exit 1
}

main() {
  local reset_token=0
  local provider="glm"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reset-token)
        reset_token=1
        ;;
      glm|claude)
        provider=$1
        ;;
      *)
        usage
        ;;
    esac
    shift
  done

  case "$provider" in
    glm)
      source "$SCRIPT_DIR/lib/providers/glm.sh"
      provider_glm_defaults
      ;;
    claude)
      source "$SCRIPT_DIR/lib/providers/claude.sh"
      provider_claude_defaults
      ;;
    *)
      aiwrap_die "Unsupported provider '$provider'. Supported providers: glm, claude"
      ;;
  esac

  install_main
  provider_config_file=$(aiwrap_provider_config_file "$provider")
  aiwrap_load_provider_config "$provider" || true

  if (( reset_token == 0 )) && aiwrap_has_usable_token "${provider_config_auth_token:-}"; then
    printf 'Using existing token in %s\n' "$provider_config_file"
    printf 'Run %s --reset-token to update it.\n' "$0"
    exit 0
  fi

  provider_config_auth_token=$(aiwrap_prompt_for_token)
  aiwrap_write_provider_config "$provider" "$provider_config_auth_token"
  printf 'Saved token to %s\n' "$provider_config_file"
}

main "$@"
