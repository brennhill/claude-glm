<p align="center">
  <img src="assets/header.svg" alt="Switchboard header" width="100%" />
</p>

# Switchboard

`switchboard` is a small launcher that lets one local AI CLI run against a different backend provider.

The core command shape is:

```bash
switchboard <tool> <provider> [tool args...]
```

This repo currently supports:

- `switchboard claude glm`
- `switchboard codex claude`

It also installs convenience shell functions:

```bash
swb() { switchboard "$@"; }
glm() { switchboard claude glm "$@"; }
```

So `glm` remains the fast path for the original Claude-on-GLM workflow, while `switchboard` is the real implementation surface.

## What It Does

Switchboard composes two layers:

- a **tool adapter** for the local CLI you want to launch
- a **provider profile** for the backend you want that CLI to talk to

For example:

- `switchboard claude glm` launches the local `claude` binary with Anthropic-style environment variables pointed at GLM / Z.ai
- `switchboard codex claude` launches the local `codex` binary with OpenAI-style environment variables pointed at a Claude provider profile

What wrappers like this can do well:

- swap base URLs
- swap auth token sources
- set default model mappings
- isolate those changes to the wrapped child process

What they do **not** guarantee:

- full protocol translation between incompatible ecosystems
- identical streaming behavior
- identical tool-calling semantics
- support for every feature each upstream CLI may assume

This version is intentionally explicit: unsupported tool/provider pairs fail instead of guessing.

## Supported Tools

- `claude`
- `codex`

## Supported Providers

- `glm`
- `claude`

## Supported Pairs

| Command | Meaning |
| --- | --- |
| `switchboard claude glm` | Run Claude Code against GLM / Z.ai |
| `switchboard codex claude` | Run Codex against a Claude provider profile |

Anything else currently fails with a clear unsupported-pair error.

## Model Mapping

### `glm` provider defaults

| Alias | Model ID |
| --- | --- |
| `haiku` | `glm-4.5-air` |
| `sonnet` | `glm-4.7` |
| `opus` | `glm-5` |

Default endpoint:

```text
https://api.z.ai/api/anthropic
```

### `claude` provider defaults

The bundled `claude` provider profile ships with placeholder defaults intended as a starting point for the `codex -> claude` path. You should review and adjust the exact values in your provider config for your environment.

## Setup

Recommended first-time setup for GLM:

```bash
scripts/setup.sh
```

That:

- checks that `claude` exists locally
- runs the installer
- prompts for the provider token
- writes provider config under `~/.aiswitchboard/providers/`

Provider-specific setup is also supported:

```bash
scripts/setup.sh glm
scripts/setup.sh claude
```

Rotate an existing provider token:

```bash
scripts/setup.sh --reset-token
scripts/setup.sh claude --reset-token
```

If a usable token already exists, setup keeps it and prints the `--reset-token` reminder instead of overwriting it silently.

## Install

If you only want the shell wiring:

```bash
scripts/install.sh
```

The installer:

- adds this repo's `bin` directory to `PATH`
- writes a managed shell block into:
  - `~/.zshrc`
  - `~/.zprofile`
  - `~/.bashrc`
  - `~/.bash_profile`
- installs `swb()` over `switchboard "$@"`
- installs the `glm()` shell function over `switchboard claude glm "$@"`
- bootstraps `~/.aiswitchboard/providers/glm.json` if it does not exist

After install, restart your shell or source the relevant rc file.

## Config Layout

Provider config lives under:

```text
~/.aiswitchboard/providers/
```

Examples:

- `~/.aiswitchboard/providers/glm.json`
- `~/.aiswitchboard/providers/claude.json`

A provider config looks like:

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

For Codex-oriented provider configs, a `models.default` key is also supported.

## Usage

Primary interface:

```bash
switchboard claude glm
switchboard claude glm --model sonnet
switchboard codex claude
```

Convenience function:

```bash
swb claude glm
glm
glm --help
glm --print "hello"
```

If a wrapped command is run interactively and its provider token is missing, Switchboard prompts for the token, saves it to the matching provider config file, and continues.

## Creating Your Own Shortcuts

Because `switchboard` is generic, you can define your own shell functions on top of it:

```bash
cclaude() { switchboard codex claude "$@"; }
cglm() { switchboard codex glm "$@"; }
```

Those examples may still fail today if the underlying pair is unsupported, but the shell pattern is the intended extension model.

## Verification

Run the current test suite:

```bash
bash tests/test_switchboard.sh
bash tests/test_setup.sh
bash tests/test_install.sh
bash tests/test_glm.sh
```

Smoke checks:

```bash
switchboard claude glm --help
switchboard codex claude --help
type swb
type glm
```

## Repo Layout

- `bin/switchboard`: primary launcher
- `assets/header.svg`: README banner image
- `scripts/install.sh`: shell installer
- `scripts/setup.sh`: interactive provider setup and token rotation
- `scripts/lib/tools/`: tool adapters
- `scripts/lib/providers/`: provider profiles
- `scripts/lib/switchboard-config.sh`: shared config helpers
- `templates/provider-glm.json.example`: seed JSON used for provider bootstrap
- `tests/test_switchboard.sh`: core dispatch tests
- `tests/test_setup.sh`: setup tests
- `tests/test_install.sh`: install tests
- `tests/test_glm.sh`: compatibility tests for the `glm()` shell function

## Troubleshooting

If `switchboard` is not found:

- open a new shell
- check that this repo's `bin` directory is on `PATH`
- rerun `scripts/install.sh`

If `glm` or `swb` is not found:

- source your shell rc file again
- run `type swb`
- run `type glm`
- confirm the managed shell block was written successfully

If setup fails because a token is missing:

- rerun `scripts/setup.sh`
- use `--reset-token` if a stale token already exists

If a command fails with an unsupported pair error:

- use one of the currently supported pairs
- or add the missing tool/provider support in this repo first
