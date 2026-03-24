# SEEDBOT - KNOWLEDGE BASE

**Generated:** 2026-03-10
**Commit:** a90e856
**Branch:** main

## OVERVIEW

Self-evolving personal assistant bootstrapped from two primitives: **coding** (via Codex CLI) and **terminal input**. Builds new capabilities on demand. Proof-of-concept that coding is the only essential primitive for a capable assistant. Entire implementation: <100 lines of Bash.

Stack: Bash, Codex CLI (GPT-5.3-Codex), cron

## STRUCTURE

seedbot/
├── assets/
├── tests/
├── AGENTS.md
├── README.md

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Main loop | `main.sh` | Input → Codex → Execute → Loop |
| System prompt | `system.md` | Instructions for Codex agent |
| Showcase examples | `assets/` | Alarm, Telegram, sudo demos |

## CONVENTIONS

### Execution Flow
```bash
# main.sh structure:
1. Read user input
2. Pass to `codex exec --full-auto`
3. Execute generated code
4. Loop
```

### Codex Invocation
```bash
codex exec --full-auto --skip-git-repo-check -
# --full-auto: No manual confirmation
# --skip-git-repo-check: Work outside git repos
# -: Read from stdin
```

### Timeout Protection
```bash
timeout 300s codex exec ...
# Prevents blocking calls (macOS: use gtimeout via GNU coreutils)
```

### Self-Evolution Pattern
- Start: only coding + terminal
- Agent writes code to add capabilities
- Code persists as new "abilities"
- Examples: cron-like alarms, Telegram bot, desktop notifications

## ANTI-PATTERNS (THIS PROJECT)

| Forbidden | Why | Reference |
|-----------|-----|-----------|
| Adding framework dependencies | Violates <100 LOC constraint | README.md |
| Blocking calls without timeout | Can freeze assistant | main.sh timeout wrapper |
| Hardcoding capabilities | Defeats self-evolution purpose | Self-building philosophy |
| Production use without Codex App Server | Shell-piped invocation is PoC only | README.md Notes |
| Committing sensitive env vars | Pack with `env.sh` template only | Checkpoint command |

## PROVEN RESULTS

**Demonstrated Capabilities** (self-built):
1. **Alarms**: Cron-like reminders via self-written scheduler
2. **Telegram**: Self-built bot for external messaging
3. **System control**: Desktop notifications, screen control (with `sudo -v`)

**Philosophy Validation**:
- Coding primitive → all other capabilities
- 100% bootstrapped from Codex CLI
- No framework bloat

**Checkpoint/Distribution**:
```bash
# Pack trained assistant with commit + mask secrets
echo "pack non-git-tracked files + commit into my_assistant.tar" | codex exec ...
```

## COMMANDS

```bash
# Run SeedBot
./main.sh

# Run with verbose Codex output
./main.sh -v

# macOS: Install dependencies
brew install coreutils bash
alias timeout=gtimeout

# Checkpoint trained assistant
echo "pack the current non-git-tracked files, with corresponding git commit, into my_assistant.tar for distribution. Remember to mask out the sensitive variables and keep non-sensitive variables in env.sh and don't pack files under logs" | codex exec --full-auto --skip-git-repo-check -
```

## QA PROCESS

### QA Gates (`.harness/run-gates.sh`)

The project uses a 6-gate QA system to ensure code quality:

| Gate | Name | Status | Description |
|------|------|--------|-------------|
| A | shellcheck / bash -n | ✅ Enabled | Syntax validation (prefers shellcheck, falls back to bash -n) |
| B | unused | ❌ Disabled | Reserved for future use |
| C | unused | ❌ Disabled | Reserved for future use |
| D | unused | ❌ Disabled | Reserved for future use |
| E | bash -n syntax validation | ✅ Enabled | Explicit bash syntax validation |
| F | shellcheck linting | ✅ Enabled | Shell script linting (requires shellcheck) |

### Running QA Gates

```bash
# Run all enabled gates
bash .harness/run-gates.sh

# Expected output:
# === seedbot QA Gates ===
#   bash -n syntax     ... PASS
#   bash -n syntax validation ... PASS
#   shellcheck         ... PASS (or SKIP if shellcheck not found)
# === Results ===
#   PASS: X  FAIL: 0
```

### Gate Configuration

Edit `.harness/config.yaml` to enable/disable gates:

```yaml
gates:
  gate_a: true   # syntax check (shellcheck or bash -n)
  gate_e: true   # bash -n syntax validation
  gate_f: true   # shellcheck linting
```

## NOTES

- **<100 LOC**: Entire implementation fits in main.sh (3394 bytes)
- **Codex over Claude Code**: Codex handles complex logic + ambiguous requests more reliably; OpenAI legal terms better for backend-in-app
- **Self-evolution**: Agent writes code to extend itself (alarms, Telegram, sudo control)
- **PoC only**: For production, use Codex App Server (not shell-piped invocation)
- **macOS setup**: Requires GNU coreutils (`gtimeout`) + modern Bash (brew install)
- **Security warning**: `sudo -v` grants temp admin access — use at own risk
- **Inspired by**: OpenClaw, nanobot
- **Distribution**: Checkpoint via tarball with commit hash + masked secrets
- **Non-blocking**: Timeout wrapper prevents infinite hangs
- **QA**: Automated gate system ensures code quality (syntax + linting)
