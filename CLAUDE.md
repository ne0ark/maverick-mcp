# CLAUDE.md

## Project Overview

This is a **Docker container wrapper** for the upstream [maverick-mcp](https://github.com/BobDenar1212/maverick-mcp) MCP (Model Context Protocol) server. It packages the MCP server with compiled TA-Lib, VectorBT, Redis, and Unraid-friendly defaults into a single container image.

The actual application source code lives upstream — this repository only contains the Dockerfile, entrypoint script, CI/CD workflows, and deployment documentation.

## Repository Structure

```
.
├── Dockerfile                          # Container image definition (python:3.12-slim base)
├── docker-entrypoint.sh                # Startup script: .env loading, cache dirs, Redis, fallbacks
├── UNRAID_DOCKER_VARIABLES.md          # Deployment guide for Unraid environments
├── .gitkeep                            # Placeholder
└── .github/
    └── workflows/
        ├── docker-publish.yml          # Build & push Docker image to Docker Hub
        └── docker.yml                  # Poll upstream for new commits, update .last_main_commit
```

## Key Architecture

### Docker Image

- **Base:** `python:3.12-slim`
- **TA-Lib:** Compiled from source (v0.6.4) during build
- **Python deps:** Installed via `pip` + `uv` — includes `vectorbt` and `maverick-mcp` (from upstream git)
- **Runtime:** `uv run --with vectorbt python -m maverick_mcp.api.server --transport sse --host 0.0.0.0 --port ${PORT:-8000}`
- **Process manager:** `tini` (PID 1 reaping)
- **User:** Runs as `99:100` (nobody:users — Unraid convention)

### Entrypoint (`docker-entrypoint.sh`)

POSIX shell script that runs before the main CMD. It:

1. Discovers and loads a `.env` file from multiple candidate paths
2. Applies `UMASK` (default `002`) for group-writable files
3. Validates writable directories (`/config`, `$HOME`, `$XDG_CACHE_HOME`, `$NUMBA_CACHE_DIR`) with automatic fallback to `/tmp` paths
4. Sets `DATABASE_URL` to a local SQLite file if not already set
5. Starts an in-container Redis daemon (localhost:6379) when Redis is enabled
6. Runs `exec "$@"` to hand off to the CMD

### CI/CD Workflows

**`docker-publish.yml`** — Builds and pushes the Docker image:
- Triggers on push to `main` or every 5 minutes via cron
- Pushes to Docker Hub as `<username>/maverick-mcp:main`
- Platform: `linux/amd64` only
- Uses GitHub Actions cache for layer caching

**`docker.yml`** — Upstream sync monitor:
- Runs every 5 minutes
- Checks the upstream `BobDenar1212/maverick-mcp` main branch for new commits
- Updates `.last_main_commit` tracker file and pushes to trigger a rebuild
- Skips push on fork repositories

## Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `8000` | MCP server port |
| `RUNTIME_DIR` | `/config` | Working directory for DB, logs, Redis data |
| `ENV_FILE` | `/config/.env` | Preferred .env file path |
| `HOME` | `/config` | Home directory for Python cache derivation |
| `XDG_CACHE_HOME` | `/config/.cache` | Cache directory for libs like yfinance |
| `NUMBA_CACHE_DIR` | `/config/.numba_cache` | JIT cache for Numba/pandas-ta |
| `UMASK` | `002` | Process umask |
| `REDIS_ENABLED` | `true` | Start in-container Redis |
| `ENABLE_REDIS_CACHE` | `true` | Upstream Redis cache toggle |
| `USE_REDIS_CACHE` | `true` | Upstream Redis cache toggle |
| `DATABASE_URL` | `sqlite:///${RUNTIME_DIR}/maverick_mcp.db` | SQLite database path |
| `REDIS_URL` | `redis://127.0.0.1:6379/0` | Redis connection URL |

## Development Conventions

### Commit Messages

Commits are concise and imperative, describing the change directly:
- `Use uv runtime with explicit VectorBT dependency`
- `Fix workflow repo sync and harden CI/env handling`
- `Harden numba cache setup and clarify TA-Lib version note`
- `Fallback runtime dir when /config is not writable`

### Branch Naming

Feature branches follow the pattern: `codex/<short-description>` or `claude/<description>`.

### Shell Script Style

- `docker-entrypoint.sh` uses POSIX `sh` (not bash) with `set -eu`
- Helper functions: `trim_with_sed()`, `load_env_file()`, `ensure_writable_dir()`
- All directory operations include graceful fallback to `/tmp` paths
- Environment variable defaults use `: "${VAR:=default}"` pattern

### Dockerfile Conventions

- Single-stage build with cleanup in the same `RUN` layer (apt purge + rm)
- Build args for configurable upstream ref/repo (`MAVERICK_MCP_REF`, `MAVERICK_MCP_REPO`)
- Non-root user (`99:100`) with pre-created writable directories
- `ENTRYPOINT` + `CMD` separation (entrypoint for setup, CMD for the server)

## Build & Run

```bash
# Build locally
docker build -t maverick-mcp .

# Run with defaults
docker run -p 8000:8000 -v /path/to/appdata:/config maverick-mcp

# Run with custom .env
docker run -p 8000:8000 -v /path/to/appdata:/config --env-file /path/to/.env maverick-mcp
```

## Important Notes for AI Assistants

- **No application source code here.** The upstream `maverick-mcp` Python package is installed at Docker build time from `https://github.com/BobDenar1212/maverick-mcp.git`. Do not look for Python application code in this repo.
- **Unraid compatibility is critical.** All changes must preserve `UID:GID 99:100`, group-writable permissions (`UMASK 002`), and `/config` as the primary writable mount point.
- **Entrypoint fallback paths matter.** The cascading fallback logic (config dir -> /tmp) ensures the container works even with misconfigured mounts. Do not simplify this away.
- **No tests in this repo.** Testing is handled upstream. CI here is purely build-and-publish.
- **Shell portability.** The entrypoint uses `/bin/sh`, not bash. Avoid bashisms.
- **Three Redis toggle variables** (`REDIS_ENABLED`, `ENABLE_REDIS_CACHE`, `USE_REDIS_CACHE`) exist for backward compatibility with different upstream versions. Keep all three.
