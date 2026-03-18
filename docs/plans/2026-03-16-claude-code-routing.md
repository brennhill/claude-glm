# Switchboard Claude Code Gateway Routing Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the product to `Switchboard` and add Claude Code-first direct and proxied routing to `switchboard`, with reusable proxy profiles, model-alias-preserving route resolution, and setup flows that keep provider and proxy config separate.

**Architecture:** Rename the current launcher to `switchboard` and extend it so it resolves a routed launch from `tool + provider (+ optional proxy)` rather than only `tool + provider`. Provider config continues to own model aliases and direct upstream defaults. Proxy config owns reusable gateway endpoints and proxy auth per protocol. Claude Code remains the primary runtime, with model selection inside Claude Code used as the switching surface after launch.

**Tech Stack:** Bash shell, `jq`, shell startup files, `expect`, Claude Code env vars, LiteLLM-compatible proxy config

---

## Execution Notes

- Treat this as a second-phase evolution of the existing implementation. Do not rewrite current docs to promise unshipped behavior.
- Rename the canonical command to `switchboard` and install `swb` as a short alias.
- Claude Code is the product center for this phase. Preserve current `codex` support where practical, but do not let it dictate config layout.
- Keep the parser deterministic:
  - `switchboard <tool> <provider>` = direct
  - `switchboard <tool> <proxy> <provider>` = proxied
  - `switchboard <tool> --proxy <proxy> <provider>` = explicit proxied equivalent
- Keep routing explicit. Do not parse prompt text to choose an upstream backend.
- Keep provider and proxy config files independent under `~/.aiswitchboard/`. Avoid adding route config files unless implementation pressure proves they are necessary.
- Preserve current-working-directory execution in every launch path.
- Keep subscription-lane messaging and gateway-lane messaging separate in docs and setup text.

## Required TDD Coverage

- `tests/test_switchboard.sh`
  - validates the renamed `switchboard` command path or compatibility shim path
  - parses direct two-argument routes
  - parses proxied three-argument routes
  - treats `--proxy` syntax as equivalent to positional proxied syntax
  - resolves provider model aliases through a proxy without rewriting them
  - rejects unknown proxy names
  - fails when a proxy lacks the endpoint for the selected protocol
  - preserves current working directory
- `tests/test_setup.sh`
  - writes provider config under `~/.aiswitchboard/providers/`
  - writes proxy config under `~/.aiswitchboard/proxies/`
  - accepts `provider` and `proxy` setup modes
  - preserves non-token fields on both config types
  - rotates provider and proxy tokens with `--reset-token`
  - fails non-interactively when a required token is missing
- `tests/test_install.sh`
  - installs `switchboard` on PATH
  - installs `swb()` as a short alias over `switchboard`
  - keeps existing `glm()` convenience behavior redirected through `switchboard`
  - remains idempotent
  - does not require proxied convenience functions to exist
- `tests/test_glm.sh`
  - keeps `glm()` as `switchboard claude glm`
  - verifies no regressions in wrapper-scoped env isolation

## File Structure

- Create: `bin/switchboard`
- Modify: `scripts/lib/switchboard-config.sh`
- Create: `scripts/lib/proxies/litellm.sh`
- Modify: `scripts/lib/providers/glm.sh`
- Modify: `scripts/lib/providers/claude.sh`
- Modify: `scripts/lib/tools/claude.sh`
- Modify: `scripts/setup.sh`
- Modify: `scripts/install.sh`
- Modify: `tests/test_switchboard.sh`
- Modify: `tests/test_install.sh`
- Modify: `tests/test_setup.sh`
- Modify: `docs/specs/2026-03-16-claude-code-routing-design.md`
- Modify: `README.md` only after implementation lands

## Chunk 1: Route Parsing and Resolution

### Task 1: Add failing tests for direct vs proxied syntax

**Files:**
- Modify: `tests/test_switchboard.sh`
- Modify: `bin/switchboard`
- Modify: `scripts/lib/switchboard-config.sh`

- [ ] **Step 1: Write the failing test**

```sh
test_switchboard_dispatches_claude_glm_direct
test_switchboard_dispatches_claude_litellm_glm_proxied
test_switchboard_dispatches_claude_proxy_flag_equivalently
test_switchboard_rejects_unknown_proxy
test_switchboard_fails_when_proxy_lacks_protocol_endpoint
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_switchboard.sh`
Expected: FAIL because current launcher does not understand proxy position or `--proxy`

- [ ] **Step 3: Write minimal implementation**

```sh
# Update switchboard config helpers to:
# - parse direct vs proxied syntax deterministically
# - load optional proxy config
# - resolve a route object with protocol, endpoint, auth token, and model aliases
# - preserve current tool args after route parsing
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_switchboard.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/test_switchboard.sh bin/switchboard scripts/lib/switchboard-config.sh
git commit -m "feat: add proxied switchboard route parsing"
```

### Flexibility and Scale Notes

- Normalize all accepted CLI forms into one internal route structure before dispatch.
- Keep parsing logic in one focused helper rather than scattering proxy conditionals through tool adapters.
- Make protocol lookup explicit so later tools can share the same route resolver.

## Chunk 2: Provider and Proxy Config Split

### Task 2: Add reusable proxy profiles and route resolution

**Files:**
- Modify: `scripts/lib/switchboard-config.sh`
- Create: `scripts/lib/proxies/litellm.sh`
- Modify: `scripts/lib/providers/glm.sh`
- Modify: `scripts/lib/providers/claude.sh`
- Modify: `scripts/lib/tools/claude.sh`
- Modify: `tests/test_switchboard.sh`

- [ ] **Step 1: Write the failing test**

```sh
test_switchboard_uses_proxy_auth_for_proxied_launch
test_switchboard_uses_provider_models_through_proxy
test_switchboard_reuses_one_proxy_profile_for_glm_and_claude
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_switchboard.sh`
Expected: FAIL because current config helpers do not load proxy profiles

- [ ] **Step 3: Write minimal implementation**

```sh
# Add proxy config loading and route resolution so:
# - provider config owns direct transport defaults and model aliases
# - proxy config owns protocol-specific endpoint URLs and proxy auth
# - routed Claude launches use proxy endpoint + proxy token + provider models
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_switchboard.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/switchboard-config.sh scripts/lib/proxies/litellm.sh scripts/lib/providers/glm.sh scripts/lib/providers/claude.sh scripts/lib/tools/claude.sh tests/test_switchboard.sh
git commit -m "feat: add switchboard proxy profiles"
```

### Flexibility and Scale Notes

- Proxy config should be protocol-scoped, not provider-scoped.
- Provider config should remain the source of truth for model family naming.
- Avoid baking LiteLLM assumptions into generic config helpers beyond what is needed for defaults and labels.

## Chunk 3: Setup Flows for Provider and Proxy Config

### Task 3: Extend setup to manage provider and proxy profiles separately

**Files:**
- Modify: `scripts/setup.sh`
- Modify: `scripts/lib/switchboard-config.sh`
- Modify: `tests/test_setup.sh`

- [ ] **Step 1: Write the failing test**

```sh
test_setup_writes_provider_config
test_setup_writes_proxy_config
test_setup_rotates_proxy_token
test_setup_preserves_proxy_non_token_fields
test_setup_rejects_unknown_setup_mode
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_setup.sh`
Expected: FAIL because setup currently only understands provider-style config

- [ ] **Step 3: Write minimal implementation**

```sh
# Extend setup to:
# - accept `provider <name>` and `proxy <name>`
# - write ~/.aiswitchboard/providers/<name>.json and ~/.aiswitchboard/proxies/<name>.json
# - preserve non-token fields
# - prompt interactively only when needed
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_setup.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/setup.sh scripts/lib/switchboard-config.sh tests/test_setup.sh
git commit -m "feat: add switchboard proxy-aware setup flows"
```

### Flexibility and Scale Notes

- Keep provider and proxy setup text distinct so users do not confuse direct credentials with gateway credentials.
- Do not auto-generate combined route files.
- Preserve the current `glm` convenience path while adding explicit proxy setup paths.

## Chunk 4: Documentation and Verification

### Task 4: Document shipped direct/proxied routing once implementation lands

**Files:**
- Modify: `README.md`
- Test: `tests/test_switchboard.sh`
- Test: `tests/test_setup.sh`
- Test: `tests/test_install.sh`
- Test: `tests/test_glm.sh`

- [ ] **Step 1: Update documentation**

```markdown
# Document direct and proxied command forms
# Explain provider config vs proxy config
# Explain Switchboard, direct/proxied command forms, and model alias strategy
# Explain subscription lane vs gateway lane without overclaiming support
```

- [ ] **Step 2: Run full suite**

Run: `bash tests/test_switchboard.sh && bash tests/test_setup.sh && bash tests/test_install.sh && bash tests/test_glm.sh`
Expected: PASS

- [ ] **Step 3: Run smoke checks**

Run: `bin/switchboard claude glm --help`
Expected: wrapped Claude help output appears

Run: `bin/switchboard claude litellm glm --help`
Expected: wrapped Claude help output appears through the proxy path with deterministic env resolution

- [ ] **Step 4: Commit**

```bash
git add README.md tests/test_switchboard.sh tests/test_setup.sh tests/test_install.sh tests/test_glm.sh
git commit -m "docs: explain switchboard claude code gateway routing"
```

### Flexibility and Scale Notes

- Keep README limited to shipped behavior only.
- Present `Switchboard` as the product name and `switchboard` as the primary command.
- Document `swb` as the short alias, not the canonical name.
- Call out that Claude Code stays the client while the gateway handles routing.
- Be explicit that gateway-backed non-Claude routes are not the same thing as Anthropic subscription-backed usage.
