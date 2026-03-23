# 🤖 Agentic Playwright Review Workflow

## Overview

An automated PR review system combining:
- **GitHub Actions** — orchestration
- **Playwright** — browser automation & runtime validation
- **LLM** — code analysis and review generation

Triggered on-demand via PR comment: `@qwen-code review`

---

## File Tree

```
playwright-demo/
├── .github/
│   └── workflows/
│       ├── agentic-pr-review.yml   # Agentic LLM review workflow
│      
├── scripts/
│   └── agentic_reviewer.js         # Core agent: Playwright + LLM + GitHub API

```

---

## Architecture

| Component | Role |
|---|---|
| `playwright.yml` | CI orchestration, env setup, artifact upload |
| `agentic_reviewer.js` | Core logic: Playwright + LLM calls + GitHub feedback |
| LLM Backend | Configurable via `LLM_BASE_URL`, `LLM_MODEL`, `LLM_API_KEY` |
| GitHub API | Posts review comments on PRs |

### Trigger Logic

```yaml
on:
  issue_comment:
    types: [created]
```

Runs only when a PR comment contains `@qwen-code review`.

---

## Execution Flow

1. **Checkout** — fetches PR branch with full git history
2. **Setup Node 20**
3. **Install deps** — `npm install` + `npx playwright install --with-deps chromium`
4. **Run reviewer** — `node scripts/agentic_reviewer.js`
5. **Upload artifacts** — screenshots, logs, traces, LLM outputs

### Key Environment Variables

| Variable | Purpose |
|---|---|
| `PR_NUMBER` | Target PR |
| `GITHUB_TOKEN` | GitHub API auth |
| `LLM_API_KEY` / `LLM_BASE_URL` / `LLM_MODEL` | LLM config |
| `APP_BASE_URL` | App under test |
| `ARTIFACTS_DIR` | Output directory |

---

## What the Reviewer Does

1. Reads PR metadata and diffs
2. Uses Playwright to navigate `APP_BASE_URL`, simulate interactions, capture screenshots/logs
3. Sends code changes + runtime observations to the LLM
4. Posts review comments to GitHub and saves artifacts to `/agent-artifacts`

---

## Strengths

- ✅ Hybrid review: static code + dynamic runtime + LLM reasoning
- ✅ On-demand triggering (no CI waste)
- ✅ Pluggable LLM layer
- ✅ Artifact preservation for debugging
- ✅ Secrets-based token handling

## Limitations

- ⚠️ No `pull_request:` trigger defined (only `issue_comment`), inconsistent with the `if` condition
- ⚠️ No caching — npm + Playwright reinstalled every run
- ⚠️ No retries for LLM or Playwright failures
- ⚠️ No structured logging or observability
- ⚠️ Prompt injection risk from PR content
- ⚠️ Tightly coupled script + workflow, hard to reuse

---

## Production-Readiness Improvements

```yaml
# Proper triggers
on:
  pull_request:
    types: [opened, synchronize]
  issue_comment:
    types: [created]
```

```yaml
# Dependency caching
- uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      ~/.cache/ms-playwright
    key: deps-${{ hashFiles('package-lock.json') }}
```

Other recommendations:
- **Retry logic** — wrap LLM calls and Playwright failures
- **Observability** — structured JSON logs, OpenTelemetry/Loki integration
- **LLM hardening** — sanitize PR content, enforce system prompt constraints
- **Modular script** — split into `playwright_runner.js`, `llm_client.js`, `review_engine.js`
- **GitHub Checks API** — pass/fail status + inline annotations instead of only comments
- **Docker** — containerized runs for determinism
- **Chunking** — for large diffs, batch LLM calls and Playwright scenarios

---

## Summary

```
Trigger → Checkout → Setup → Execute Agent →
    (Code + Runtime Analysis) →
        LLM Reasoning →
            GitHub Feedback + Artifacts
```

A solid modern architecture for AI-assisted PR review. Needs resilience, observability, and security hardening before production use.
