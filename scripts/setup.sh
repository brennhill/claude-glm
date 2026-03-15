#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/install.sh"
source "$SCRIPT_DIR/lib/glm-config.sh"

usage() {
  printf 'Usage: %s [--reset-token]\n' "$0" >&2
  exit 1
}

main() {
  local reset_token=0

  case "${1-}" in
    "")
      ;;
    --reset-token)
      reset_token=1
      ;;
    *)
      usage
      ;;
  esac

  glm_require_claude >/dev/null
  install_main
  glm_load_config

  if (( reset_token == 0 )) && glm_has_usable_token "${GLM_AUTH_TOKEN:-$config_auth_token}"; then
    printf 'Using existing token in %s\n' "$GLM_CONFIG_FILE"
    printf 'Run %s --reset-token to update it.\n' "$0"
    exit 0
  fi

  config_auth_token=$(glm_prompt_for_token)
  glm_write_config "$config_auth_token"
  printf 'Saved token to %s\n' "$GLM_CONFIG_FILE"
}

main "$@"
