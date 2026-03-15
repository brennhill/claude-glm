# GLM Wrapper Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reproducible `glm` command that wraps Claude Code with GLM/Z.ai Anthropic-compatible settings, plus an interactive setup flow that captures and persists the API token.

**Architecture:** Keep wrapper logic in a repo-managed shell executable under `bin/`, install it by adding the repo's `bin` directory to shell startup files, and store secrets in `~/.zai.json`. Add `scripts/setup.sh` for explicit onboarding, and teach `bin/glm` to prompt interactively on first use when the token is missing. The wrapper merges `GLM_*` overrides, config-file values, and built-in defaults, then `exec`s `claude` with mapped `ANTHROPIC_*` variables scoped only to the child process.

**Tech Stack:** POSIX shell, `bash`/`zsh` startup files, optional `jq`, shell-based tests

---

## File Structure

- Create: `bin/glm`
- Create: `scripts/install.sh`
- Create: `scripts/setup.sh`
- Create: `templates/zai.json.example`
- Create: `tests/test_glm.sh`
- Create: `tests/test_install.sh`
- Create: `tests/test_setup.sh`

## Chunk 1: Wrapper Behavior

### Task 1: Add config and env precedence tests

**Files:**
- Create: `tests/test_glm.sh`
- Create: `templates/zai.json.example`
- Test: `tests/test_glm.sh`

- [ ] **Step 1: Write the failing test**

```sh
test_wrapper_env_output_redacts_token_and_uses_defaults
test_wrapper_prefers_glm_env_over_config
test_wrapper_requires_auth_token
test_wrapper_prompts_interactively_when_token_missing
test_wrapper_fails_non_interactively_when_token_missing
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_glm.sh`
Expected: FAIL because `bin/glm` does not exist yet

- [ ] **Step 3: Write minimal implementation**

```sh
# Create bin/glm with:
# - built-in defaults
# - ~/.zai.json loading
# - GLM_* overrides
# - `glm env` redacted output
# - first-run interactive token prompt
# - non-interactive failure path
# - `exec env ... claude "$@"`
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_glm.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/test_glm.sh templates/zai.json.example bin/glm
git commit -m "feat: add glm wrapper"
```

## Chunk 2: Installer Behavior

### Task 2: Add installer idempotence tests

**Files:**
- Create: `tests/test_install.sh`
- Create: `scripts/install.sh`
- Test: `tests/test_install.sh`

- [ ] **Step 1: Write the failing test**

```sh
test_install_updates_zsh_and_bash_rc_files_once
test_install_creates_example_config_with_restricted_permissions
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_install.sh`
Expected: FAIL because `scripts/install.sh` does not exist yet

- [ ] **Step 3: Write minimal implementation**

```sh
# Create scripts/install.sh with:
# - repo root detection
# - managed PATH block insertion
# - no duplicate block on rerun
# - optional ~/.zai.json bootstrap with chmod 600
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_install.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/test_install.sh scripts/install.sh
git commit -m "feat: add glm installer"
```

## Chunk 3: Setup Script

### Task 3: Add interactive setup script tests

**Files:**
- Create: `tests/test_setup.sh`
- Create: `scripts/setup.sh`
- Modify: `scripts/install.sh`
- Test: `tests/test_setup.sh`

- [ ] **Step 1: Write the failing test**

```sh
test_setup_prompts_for_token_and_writes_config
test_setup_preserves_existing_non_token_config
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_setup.sh`
Expected: FAIL because `scripts/setup.sh` does not exist yet

- [ ] **Step 3: Write minimal implementation**

```sh
# Create scripts/setup.sh with:
# - installer invocation
# - claude presence check
# - interactive token prompt
# - config update that preserves base_url and models
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_setup.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/test_setup.sh scripts/setup.sh scripts/install.sh
git commit -m "feat: add interactive glm setup"
```

## Chunk 4: End-to-End Verification

### Task 4: Verify the full setup

**Files:**
- Modify: `bin/glm`
- Modify: `scripts/install.sh`
- Modify: `scripts/setup.sh`
- Test: `tests/test_glm.sh`
- Test: `tests/test_install.sh`
- Test: `tests/test_setup.sh`

- [ ] **Step 1: Run wrapper tests**

Run: `bash tests/test_glm.sh`
Expected: PASS

- [ ] **Step 2: Run installer tests**

Run: `bash tests/test_install.sh`
Expected: PASS

- [ ] **Step 3: Run setup tests**

Run: `bash tests/test_setup.sh`
Expected: PASS

- [ ] **Step 4: Run a live smoke check against Claude CLI**

Run: `bin/glm --help`
Expected: Claude help output appears through the wrapper path

- [ ] **Step 5: Check redacted debug output**

Run: `GLM_AUTH_TOKEN=test-token bin/glm env`
Expected: printed config shows redacted token, not the raw token

- [ ] **Step 6: Commit**

```bash
git add bin/glm scripts/install.sh scripts/setup.sh tests/test_glm.sh tests/test_install.sh tests/test_setup.sh templates/zai.json.example
git commit -m "test: verify glm setup end to end"
```
