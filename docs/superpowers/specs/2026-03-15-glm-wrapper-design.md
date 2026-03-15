# GLM Wrapper Design

**Date:** 2026-03-15

**Goal:** Provide a reproducible local setup that exposes a `glm` terminal command which runs Claude Code against GLM/Z.ai endpoints by shadowing Anthropic environment variables only for the wrapped process, with interactive token setup on first use.

## Context

The repository is currently empty. The user wants a setup that can be installed on any laptop, exposes `glm` in the shell, supports both `zsh` and `bash`, stores secrets outside the repo, and does not disrupt unrelated terminals by exporting Anthropic variables globally.

## Chosen Approach

Use a repo-managed wrapper plus an idempotent installer and interactive setup flow:

- Store the wrapper logic in versioned files in this repo.
- Add a dedicated setup script that prompts for the Z.ai token.
- Add this repo's `bin` directory to the user's shell `PATH`.
- Keep sensitive configuration in `~/.zai.json`.
- Allow `GLM_*` environment variables to override file-based values.
- Map `GLM_*` values to `ANTHROPIC_*` only within the `glm` wrapper process before `exec`ing `claude`.
- If `glm` is run interactively without a usable token, prompt once, save the token, and continue.

## Alternatives Considered

### 1. Repo-managed wrapper plus shell hook

Recommended because it is easy to reproduce, easy to update, and keeps shell-specific customization minimal.

### 2. Shell-function-only installation

Rejected because embedding all logic in shell rc files is harder to version, test, and port across machines.

### 3. Generated executable in a global user bin directory

Rejected because it spreads behavior across more locations and is less obviously tied to this repo.

## Command Interface

The wrapper will expose a `glm` command which forwards arbitrary arguments to the installed `claude` binary.

Configuration sources, highest precedence first:

1. Current-process `GLM_*` environment variables
2. `~/.zai.json`
3. Built-in defaults

Supported `GLM_*` environment variables:

- `GLM_BASE_URL`
- `GLM_AUTH_TOKEN`
- `GLM_DEFAULT_HAIKU_MODEL`
- `GLM_DEFAULT_SONNET_MODEL`
- `GLM_DEFAULT_OPUS_MODEL`

Mapped internal variables for the child process:

- `ANTHROPIC_BASE_URL`
- `ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_DEFAULT_HAIKU_MODEL`
- `ANTHROPIC_DEFAULT_SONNET_MODEL`
- `ANTHROPIC_DEFAULT_OPUS_MODEL`

Built-in defaults:

- Base URL: `https://api.z.ai/api/anthropic`
- Haiku model: `glm-4.5-air`
- Sonnet model: `glm-4.7`
- Opus model: `glm-5`

The wrapper will also support a redacted debug command, `glm env`, to print the effective configuration without exposing the auth token.

## Installation

The repo will contain:

- `bin/glm`: wrapper executable
- `scripts/install.sh`: idempotent installer
- `scripts/setup.sh`: interactive onboarding entrypoint
- `templates/zai.json.example`: example configuration
- shell-based tests for installer and wrapper behavior

The installer will:

- Detect `zsh` and `bash` startup files
- Append a clearly delimited managed block that prepends this repo's `bin` directory to `PATH`
- Avoid duplicating the block on repeated runs
- Create `~/.zai.json` from the example if it does not already exist
- Apply restrictive permissions to the config file

The setup script will:

- Verify `claude` exists
- Run the installer
- Prompt for the token if `~/.zai.json` is missing or still contains the placeholder token
- Preserve existing non-token config values
- Save the token with restrictive file permissions

## Config File Schema

The config file schema is intentionally narrow:

```json
{
  "base_url": "https://api.z.ai/api/anthropic",
  "auth_token": "your-zai-api-key",
  "models": {
    "haiku": "glm-4.5-air",
    "sonnet": "glm-4.7",
    "opus": "glm-5"
  }
}
```

## Failure Handling

- If `claude` is not installed, exit with a targeted error.
- If no auth token is available from `GLM_AUTH_TOKEN` or `~/.zai.json`, prompt only when the session is interactive; otherwise exit with a targeted error.
- If `~/.zai.json` is malformed, fail fast and point to the example config rather than guessing.
- If `jq` is unavailable, use a narrow fallback parser sufficient for the fixed schema above.
- Treat the placeholder token `your-zai-api-key` as missing.
- Do not overwrite malformed config automatically.

## Testing Strategy

Behavioral tests will cover:

- Effective config precedence
- Redaction in `glm env`
- No shell contamination from Anthropic variables
- Installer idempotence
- Interactive setup token capture
- Interactive first-run prompting in `glm`
- Non-interactive failure when the token is missing
- Forwarding of arbitrary Claude arguments

## Boundaries

- Keep implementation in shell for portability.
- Avoid changing global Anthropic variables outside the wrapped process.
- Avoid adding features beyond installation, config loading, env mapping, and validation.
