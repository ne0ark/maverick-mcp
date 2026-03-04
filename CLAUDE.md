# CLAUDE.md — maverick-mcp Docker Wrapper

## What This Repository Is

This is a **Docker distribution/packaging repository** for the upstream [maverick-mcp](https://github.com/BobDenar1212/maverick-mcp) Model Context Protocol (MCP) server. It does **not** contain the application source code — it provides:

- A `Dockerfile` that builds an image pulling upstream maverick-mcp from GitHub
- A `docker-entrypoint.sh` startup script with environment/permission orchestration
- GitHub Actions CI/CD for automated Docker image builds
- Documentation for Unraid NAS deployments

The actual MCP server code lives at `https://github.com/BobDenar1212/maverick-mcp.git`.

## Repository Structure

```
.
├── Dockerfile                     # Docker image definition (Python 3.12-slim base)
├── docker-entrypoint.sh           # Container startup script (POSIX shell)
├── UNRAID_DOCKER_VARIABLES.md     # Unraid-specific setup documentation
├── .github/
│   └── workflows/
│       ├── docker.yml             # Build & push Docker image on push/schedule
│       └── docker-publish.yml     # Track upstream main branch for new commits
├── .gitkeep
└── CLAUDE.md                      # This file
```

## Key Files

### Dockerfile
- **Base image:** `python:3.12-slim`
- **Installs:** TA-Lib (C library v0.6.4), Redis, tini, uv, vectorbt, then the upstream maverick-mcp via pip from git
- **Runs as:** UID:GID `99:100` (Unraid `nobody:users`)
- **Exposes:** port 8000 (HTTP/SSE)
- **Entry point:** tini → docker-entrypoint.sh → `uv run --with vectorbt python -m maverick_mcp.api.server`
- **Build args:** `MAVERICK_MCP_REF` (git branch/tag), `MAVERICK_MCP_REPO` (git URL), `TA_LIB_VERSION`

### docker-entrypoint.sh
- POSIX-compliant shell script (`set -eu`)
- Loads `.env` from multiple candidate paths (ENV_FILE, RUNTIME_DIR/.env, /config/.env, /workspace/.env)
- Custom `load_env_file()` parser supporting `KEY=VALUE`, `export KEY=VALUE`, comments, and quoted values
- Ensures writable directories for HOME, XDG_CACHE_HOME, NUMBA_CACHE_DIR with `/tmp` fallbacks
- Sets up SQLite DATABASE_URL if not already configured
- Starts embedded Redis server if REDIS_ENABLED/ENABLE_REDIS_CACHE/USE_REDIS_CACHE is `true`

### CI/CD Workflows

**docker.yml** — Builds and pushes the Docker image:
- Triggers on push to `main` and on a 5-minute cron schedule
- Publishes to Docker Hub as `<username>/maverick-mcp:main`
- Uses Docker Buildx with GitHub Actions cache
- Requires secrets: `DOCKER_HUB_USERNAME`, `DOCKER_HUB_ACCESS_TOKEN`

**docker-publish.yml** — Tracks upstream for new commits:
- Polls `BobDenar1212/maverick-mcp` main branch every 5 minutes via GitHub API
- Stores latest commit SHA in `.last_main_commit`
- Auto-commits the update (skips on forks)

## Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `8000` | HTTP/SSE server port |
| `RUNTIME_DIR` | `/config` | Working directory for runtime data |
| `HOME` | `/config` | Home directory |
| `DATABASE_URL` | `sqlite:///config/maverick_mcp.db` | Database connection string |
| `REDIS_ENABLED` | `true` | Enable embedded Redis |
| `REDIS_URL` | `redis://127.0.0.1:6379/0` | Redis connection URL |
| `XDG_CACHE_HOME` | `/config/.cache` | Python/pip cache directory |
| `NUMBA_CACHE_DIR` | `/config/.numba_cache` | Numba JIT cache directory |
| `ENV_FILE` | `${RUNTIME_DIR}/.env` | Custom .env file path |
| `UMASK` | `002` | File creation mask |

## Development Conventions

### Branching
- Feature branches: `codex/<description>` or `claude/<description>`
- PRs merge into `main`
- Commit messages are descriptive; merge commits reference PR numbers

### Shell Scripts
- POSIX shell (`#!/bin/sh`), not Bash — no bashisms
- Use `set -eu` for strict error handling
- Include fallback logic for all writable directory operations
- Test file/directory access before use; never assume paths are writable

### Dockerfile
- Minimize layers; chain RUN commands with `&&`
- Clean up build dependencies and apt lists after install
- Keep the non-root user pattern (99:100) for Unraid compatibility
- Use build args for anything that might change between builds (repo URL, ref, library versions)

### CI/CD
- Workflows use `paths-ignore` to avoid unnecessary rebuilds on docs/config changes
- Docker images are multi-platform but currently only build `linux/amd64`
- Secrets are managed via GitHub repository settings

## Build & Test Commands

There are no local build/test/lint commands in this repo. All operations are Docker-based:

```bash
# Build the Docker image locally
docker build -t maverick-mcp .

# Build with a specific upstream branch
docker build --build-arg MAVERICK_MCP_REF=main -t maverick-mcp .

# Run the container
docker run -p 8000:8000 -v ./config:/config maverick-mcp

# Run with custom env file
docker run -p 8000:8000 -v ./config:/config -e ENV_FILE=/config/.env maverick-mcp
```

## Common Pitfalls

- **No local source code to edit** — the MCP server code is pulled at Docker build time from upstream. To change application behavior, modify the upstream repo or override via environment variables.
- **TA-Lib build takes time** — the C library is compiled from source during Docker build; expect longer build times.
- **Permission issues on Unraid** — the container runs as 99:100; volumes must be owned by or writable to this UID/GID.
- **Redis runs in-process** — Redis is started inside the container by the entrypoint script, not as a separate service.
- **`.last_main_commit` is auto-managed** — do not manually edit this file; it is updated by the CI workflow.
