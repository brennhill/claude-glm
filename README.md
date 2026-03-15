# GLM Wrapper for Claude Code

This repo installs a `glm` command that wraps the local `claude` CLI and points it at the GLM/Z.ai Anthropic-compatible API without exporting Anthropic variables into every terminal.

The wrapper shadows these variables only for the `claude` child process:

- `ANTHROPIC_BASE_URL`
- `ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_DEFAULT_HAIKU_MODEL`
- `ANTHROPIC_DEFAULT_SONNET_MODEL`
- `ANTHROPIC_DEFAULT_OPUS_MODEL`

Default mappings:

- `ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic`
- `ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air`
- `ANTHROPIC_DEFAULT_SONNET_MODEL=glm-4.7`
- `ANTHROPIC_DEFAULT_OPUS_MODEL=glm-5`

## Requirements

- Claude Code CLI installed and available as `claude`
- `zsh` and/or `bash`
- `jq` is supported if present, but not required

Check that Claude is installed:

```bash
command -v claude
```

## Setup

Recommended first-time setup:

```bash
scripts/setup.sh
```

`scripts/setup.sh`:

- checks that `claude` is installed
- runs the shell installer
- prompts for your Z.ai API key
- writes the token into `~/.zai.json`
- preserves existing base URL and model mappings if the config already exists

If a usable token already exists, `scripts/setup.sh` keeps it and prints a reminder that you can rotate it with:

```bash
scripts/setup.sh --reset-token
```

That flag prompts for a new key and updates only `auth_token`.

## Install Only

If you only want the shell wiring and do not want to enter the token yet:

From this repo:

```bash
scripts/install.sh
```

The installer:

- adds this repo's `bin` directory to your shell startup files
- updates:
  - `~/.zshrc`
  - `~/.zprofile`
  - `~/.bashrc`
  - `~/.bash_profile`
- creates `~/.zai.json` from the example template if it does not already exist
- sets `~/.zai.json` permissions to `600`

After install, reload your shell:

```bash
source ~/.zshrc
```

Or for bash:

```bash
source ~/.bashrc
```

You can also just open a new terminal and run:

```bash
command -v glm
```

Expected result:

```text
/absolute/path/to/this/repo/bin/glm
```

## Configure `~/.zai.json`

The installer creates this file if missing:

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

Replace `"your-zai-api-key"` with your real Z.ai key before using `glm`, or just run:

```bash
scripts/setup.sh
```

## Environment Variable Overrides

You can override the config file on a per-command basis with `GLM_*` variables:

- `GLM_BASE_URL`
- `GLM_AUTH_TOKEN`
- `GLM_DEFAULT_HAIKU_MODEL`
- `GLM_DEFAULT_SONNET_MODEL`
- `GLM_DEFAULT_OPUS_MODEL`

Example:

```bash
GLM_AUTH_TOKEN=your-real-token glm --help
```

The wrapper maps those to the `ANTHROPIC_*` variables only for the wrapped `claude` process.

## Usage

Run Claude Code against GLM:

```bash
glm
```

If `glm` is run interactively and no usable token is configured, it will prompt for the token, save it to `~/.zai.json`, and continue.

Pass arbitrary Claude arguments through unchanged:

```bash
glm --help
glm --print "hello"
glm -c
```

Inspect the effective wrapped environment with token redaction:

```bash
glm env
```

Example output:

```text
ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
ANTHROPIC_AUTH_TOKEN=test...oken
ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air
ANTHROPIC_DEFAULT_SONNET_MODEL=glm-4.7
ANTHROPIC_DEFAULT_OPUS_MODEL=glm-5
```

## Behavior

Configuration precedence is:

1. `GLM_*` environment variables
2. `~/.zai.json`
3. built-in defaults

The wrapper will fail fast when:

- `claude` is not installed
- no auth token is configured in a non-interactive context
- the config file is malformed
- the config still contains the placeholder token

## Files

- `bin/glm`: wrapper executable
- `scripts/install.sh`: idempotent installer
- `templates/zai.json.example`: example config template
- `tests/test_glm.sh`: wrapper tests
- `tests/test_install.sh`: installer tests

## Verify

Run the test suite:

```bash
bash tests/test_glm.sh
bash tests/test_install.sh
```

Smoke test the wrapper:

```bash
GLM_AUTH_TOKEN=your-real-token glm env
GLM_AUTH_TOKEN=your-real-token glm --help
```

Or test the guided flow:

```bash
scripts/setup.sh
glm
```

Rotate the saved token:

```bash
scripts/setup.sh --reset-token
```

## Troubleshooting

If `glm` is not found:

- open a new terminal, or source your shell startup file
- verify the installer block exists in your rc/profile files
- run `command -v glm`

If `glm` says the auth token is required:

- run `scripts/setup.sh`, or
- set `auth_token` in `~/.zai.json`, or
- use `GLM_AUTH_TOKEN=... glm ...`

If `glm` says the placeholder token must be replaced:

- edit `~/.zai.json` and replace `"your-zai-api-key"` with the real value

If Claude still points at Anthropic in other terminals:

- that is expected unless you exported `ANTHROPIC_*` yourself
- this wrapper only shadows those variables for the `glm` process tree
