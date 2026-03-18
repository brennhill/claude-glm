# Switchboard Claude Code Gateway Routing Design

**Date:** 2026-03-16

**Goal:** Evolve the current wrapper into `Switchboard`, a Claude Code-first routing tool that can launch Claude Code directly against a provider or through a reusable LiteLLM-style proxy, while keeping model aliases as the main routing surface inside the running Claude Code session.

## Context

The current repo already ships a generalized `switchboard` launcher with support for:

- `switchboard claude glm`
- `switchboard codex claude`

That implementation works as a wrapper, but the clarified product direction is narrower and more useful:

- the user wants to keep using Claude Code as the primary client and orchestration layer
- LiteLLM or another gateway should handle routing, observability, and multi-provider access
- switching between routed backends should happen through Claude Code model selection rather than by relaunching Claude Code

This means the product should become `Switchboard`, a bootstrap layer for Claude Code routing rather than a replacement for Claude Code.

## Chosen Approach

Build the next phase around three concepts:

- **tool**: the local CLI being launched, with Claude Code as the primary supported workflow
- **provider**: the upstream model family and direct transport defaults, such as `glm` or `claude`
- **proxy**: an optional reusable gateway profile, such as `litellm`

`switchboard` resolves those pieces into a single routed Claude Code launch:

- direct mode: provider transport and provider credentials
- proxied mode: proxy transport and proxy credentials, plus provider model aliases

The routing decision should be explicit in the command line and explicit in the model name or alias sent to the gateway. Do not rely on prompt inspection or hidden heuristics to choose an upstream backend.

## Command Interface

Recommended user-facing forms:

```bash
switchboard <tool> <provider> [tool args...]
switchboard <tool> <proxy> <provider> [tool args...]
switchboard <tool> --proxy <proxy> <provider> [tool args...]
```

Examples:

```bash
switchboard claude glm
switchboard claude litellm glm
switchboard claude --proxy litellm claude
```

Command semantics:

- two route arguments after the tool means direct mode
- three route arguments after the tool means proxied mode
- `--proxy <name>` is the explicit equivalent of the three-positional proxied form

The positional proxied form is the ergonomic shorthand. The `--proxy` form exists for readability in scripts and automation.

## Claude Code-First Runtime Model

The central workflow is:

1. launch Claude Code once through `switchboard`
2. point Claude Code either directly at a provider or at a gateway such as LiteLLM
3. use Claude Code model selection as the runtime routing surface

This keeps Claude Code responsible for:

- session state
- orchestration
- subagents
- slash commands and workflow

It keeps the gateway responsible for:

- routing
- observability
- retries and fallbacks
- upstream credentials
- provider fan-out

It keeps `switchboard` responsible for:

- turning local config into a valid routed launch
- injecting env vars only into the wrapped child process
- making direct and proxied launches ergonomic

## Model Routing Strategy

Model aliases are the main switching surface.

For Claude Code this means:

- the Claude Code session can stay alive
- model changes can happen inside the session
- route selection can be expressed by switching model aliases or mapped model names

For proxied launches:

- provider profiles define the model family and alias mapping
- proxy profiles define the endpoint and proxy auth
- Claude Code sends model names to the proxy
- the proxy routes those model names to the chosen upstream backend

For example, a proxied `glm` provider can expose:

- `haiku` -> `glm-4.5-air`
- `sonnet` -> `glm-4.7`
- `opus` -> `glm-5`

And a proxied `claude` provider can expose:

- `haiku` -> a Claude-compatible or gateway-mapped small model
- `sonnet` -> a Claude-compatible or gateway-mapped balanced model
- `opus` -> a Claude-compatible or gateway-mapped strong model

This allows one Claude Code session to change routes by changing the selected model alias, as long as the gateway understands those model names.

## Configuration Model

Keep user config under `~/.aiswitchboard/` and split direct-provider config from reusable proxy config.

Provider config:

```text
~/.aiswitchboard/providers/<provider>.json
```

Example:

```json
{
  "auth_label": "Z.ai",
  "models": {
    "haiku": "glm-4.5-air",
    "sonnet": "glm-4.7",
    "opus": "glm-5"
  },
  "direct": {
    "anthropic": {
      "base_url": "https://api.z.ai/api/anthropic",
      "auth_token": "provider-token"
    }
  }
}
```

Proxy config:

```text
~/.aiswitchboard/proxies/<proxy>.json
```

Example:

```json
{
  "auth_label": "LiteLLM",
  "auth_token": "proxy-token",
  "protocols": {
    "anthropic": {
      "base_url": "http://localhost:4000/anthropic"
    },
    "openai": {
      "base_url": "http://localhost:4000/v1"
    }
  }
}
```

Resolution rules:

- direct mode uses `provider.direct.<protocol>`
- proxied mode uses `proxy.protocols.<protocol>` plus the provider's `models`
- provider identity never comes from the proxy
- proxy identity never redefines the provider model family

## Subscription and Gateway Boundary

This design must stay honest about Anthropic support boundaries.

Supported mental model:

- Claude Code remains the official client and workflow
- gateways such as LiteLLM are used for API-backed routing and observability
- `switchboard` helps bootstrap Claude Code into that routed environment

Non-goal:

- claiming that an Anthropic consumer subscription pays for non-Anthropic routed traffic
- claiming that third-party clients can safely consume Claude subscription access

Practical rule:

- **subscription lane**: Claude Code using direct Claude authentication
- **gateway lane**: Claude Code using gateway or API credentials for routed traffic

The product can preserve Claude Code UX across both lanes, but it must not blur the billing or policy boundary between them.

## Setup and Installation

Keep installation and setup separate.

Installer responsibilities:

- add repo `bin` to `PATH`
- install convenience shell functions such as `glm() { switchboard claude glm "$@"; }`
- install a short alias such as `swb() { switchboard "$@"; }`
- optionally install proxied convenience functions later, but do not require them

Setup responsibilities:

- `scripts/setup.sh provider <name>`
- `scripts/setup.sh proxy <name>`
- `scripts/setup.sh provider <name> --reset-token`
- `scripts/setup.sh proxy <name> --reset-token`

Setup should:

- prompt only when interactive
- write provider and proxy config independently
- preserve non-token settings on rerun
- avoid inventing combined route config files unless the direct/proxy split proves insufficient

## Failure Handling

- unknown tool: print supported tools
- unknown provider: print supported providers
- unknown proxy: print supported proxies
- missing provider token in direct mode: prompt if interactive, otherwise fail
- missing proxy token in proxied mode: prompt if interactive, otherwise fail
- proxy missing required protocol endpoint: fail explicitly
- malformed provider or proxy config: fail without auto-overwriting
- unsupported tool/provider/protocol combination: fail explicitly

## Testing Strategy

Behavioral coverage for the next phase should include:

- direct two-argument dispatch
- proxied three-argument dispatch
- `--proxy` equivalence with positional proxied syntax
- provider model aliases surviving through proxy resolution
- shared proxy profile reused across multiple providers
- current working directory preserved
- setup for provider config and proxy config
- interactive prompting for missing direct or proxy tokens
- clear failures for missing protocol endpoints

## Boundaries

- Claude Code is the primary workflow for this phase.
- Preserve existing functionality where practical, but do not let `codex` drive the architecture.
- Do not implement prompt-parsing routing hooks as the main path.
- Prefer explicit model alias routing over hidden dynamic heuristics.
- Keep current documentation honest: only document shipped runtime behavior in `README.md`; future Switchboard behavior belongs in the spec and plan until implemented.
