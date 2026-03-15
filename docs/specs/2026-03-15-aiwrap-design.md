# AIWrap Design

**Date:** 2026-03-15

**Goal:** Replace the single-purpose GLM wrapper with a generalized `aiwrap` command that can launch different local AI CLIs against different backend providers, starting with `claude` and `codex` as tools and `glm` plus `claude` as providers.

## Context

The current repo implements a GLM-specific wrapper around Claude Code. The next iteration should generalize that pattern so the same framework can support pairings like:

- `aiwrap claude glm`
- `aiwrap codex claude`

The user wants `aiwrap` to be the real command, with convenience shell aliases layered on top. Existing one-off local usage means full backward compatibility is not required, but the installer should keep a `glm` convenience alias that delegates to `aiwrap claude glm`.

## Chosen Approach

Build a two-layer launcher framework:

- **Tool adapters** define how to launch a local CLI such as `claude` or `codex`.
- **Provider profiles** define endpoint, auth, and model defaults for a target backend such as `glm` or `claude`.

`aiwrap` composes one tool adapter with one provider profile and then launches the selected CLI in the current working directory with tool-specific environment variables derived from provider-neutral config.

## Command Interface

Primary command:

```bash
aiwrap <tool> <provider> [tool args...]
```

Examples:

```bash
aiwrap claude glm
aiwrap claude glm --model sonnet
aiwrap codex claude
```

Convenience aliases are shell-level only. The installer should define:

```bash
glm() { aiwrap claude glm "$@"; }
```

This preserves the user's current shorthand while centralizing the implementation in `aiwrap`.

## Supported Tools and Providers

Initial tool adapters:

- `claude`
- `codex`

Initial provider profiles:

- `glm`
- `claude`

Unsupported pairs should fail explicitly with a clear error rather than guessing.

## Configuration Model

Move to a neutral config location:

- `~/.aiwrap/providers/glm.json`
- `~/.aiwrap/providers/claude.json`

Each provider config contains neutral fields:

```json
{
  "base_url": "https://api.z.ai/api/anthropic",
  "auth_token": "your-provider-key",
  "models": {
    "haiku": "glm-4.5-air",
    "sonnet": "glm-4.7",
    "opus": "glm-5"
  }
}
```

Provider profiles supply defaults and config file locations. Tool adapters translate those neutral values into tool-specific launch environment.

## Adapter Responsibilities

### Tool adapters

Each tool adapter must define:

- local binary name
- required launch-time environment variables
- supported configuration translation
- optional validation for incompatible model flags or unsupported settings

### Provider profiles

Each provider profile must define:

- default endpoint
- token storage path
- default model mapping
- required auth semantics

## Setup and Installation

The repo will provide:

- `bin/aiwrap`: primary executable
- `scripts/setup.sh`: provider-aware onboarding
- `scripts/install.sh`: shell installation
- tool and provider library scripts under `scripts/lib/`

Installer behavior:

- add repo `bin` to shell startup files
- define `glm()` as `aiwrap claude glm "$@"`
- optionally include commented examples for other aliases

Setup behavior:

- `scripts/setup.sh [provider]`
- default provider is `glm`
- verify required local tooling
- prompt for provider token if missing
- write provider config into `~/.aiwrap/providers/<provider>.json`
- preserve existing non-token provider settings
- support token rotation with `--reset-token`

## Failure Handling

- unknown tool: print supported tools
- unknown provider: print supported providers
- missing token: prompt only in interactive mode, otherwise fail
- malformed config: fail without auto-overwriting
- unsupported tool/provider pair: fail explicitly

## Migration

No full backward-compatibility layer is required.

During implementation:

- local machine config can be moved manually from `~/.zai.json` into `~/.aiwrap/providers/glm.json`
- `bin/glm` can be removed as a real executable
- shell startup files should define `glm()` as a convenience alias over `aiwrap`

## Testing Strategy

Behavioral tests should cover:

- tool/provider dispatch
- provider config loading
- token prompting and persistence
- shell alias installation
- unsupported pair errors
- current-directory execution behavior
- `glm` alias delegating to `aiwrap claude glm`

## Boundaries

- Start with `claude` and `codex` only as local tools.
- Start with `glm` and `claude` only as provider profiles.
- Avoid generated per-pair binaries in the first version.
- Keep the implementation shell-based unless a stronger need emerges.
