# Environment Variable Reference — maverick-mcp

Complete reference for all environment variables used by the `ne0ark/maverick-mcp` Docker image, including container infrastructure, build-time, and upstream MaverickMCP application variables.

---

## Container Infrastructure Variables

These variables control the container's runtime behavior. They are set in the Dockerfile and processed by the entrypoint script (`docker-entrypoint.sh`).

| Variable | Default | Required | Description |
|---|---|---|---|
| `HOME` | `/config` | No | Home directory override. Used by Python libraries that derive cache paths from `$HOME` (e.g., yfinance). Set to `/config` so caches persist across restarts. |
| `XDG_CACHE_HOME` | `/config/.cache` | No | Base writable cache directory for libraries using the XDG specification. Falls back to `/tmp/.cache` if not writable. |
| `NUMBA_CACHE_DIR` | `/config/.numba_cache` | No | Cache directory for Numba JIT compilation (used by pandas-ta). Prevents cache errors on read-only site-packages. Falls back to `/tmp/.numba_cache` if not writable. |
| `UMASK` | `002` | No | Process umask applied at container startup. `002` ensures group-writable files on Unraid shares. |
| `PORT` | `8000` | No | Port variable for compatibility with existing `.env` files. The default CMD binds to port 8000 via `${PORT:-8000}`. |
| `TRANSPORT` | `sse` | No | MCP transport protocol. Options: `sse` (SSE on `/sse/`), `streamable-http` (HTTP on `/mcp/`). See [Transport Modes](#transport-modes) below. |
| `RUNTIME_DIR` | `/config` | No | Working directory for runtime writes: SQLite database, logs, and Redis data. Falls back to `/tmp/maverick-mcp` if not writable. |
| `ENV_FILE` | `/config/.env` | No | Explicit path to the `.env` file. The entrypoint searches for a readable file at `$ENV_FILE`, then `$RUNTIME_DIR/.env`, then `/config/.env`, then `/workspace/.env`. |
| `UV_CACHE_DIR` | `/tmp/uv-cache` | No | Cache directory for the `uv` Python package manager. Set to `/tmp` since it doesn't need persistence. |
| `REDIS_ENABLED` | `true` | No | Master toggle for Redis. When `true`, the entrypoint starts an in-container Redis server if not already running. |
| `ENABLE_REDIS_CACHE` | `true` | No | Compatibility toggle for upstream Redis cache integration. Kept enabled by default. |
| `USE_REDIS_CACHE` | `true` | No | Compatibility toggle for upstream Redis cache integration. Kept enabled by default. |
| `DATABASE_URL` | `sqlite:///${RUNTIME_DIR}/maverick_mcp.db` | No | Database connection string. Defaults to SQLite in the runtime directory. Set to a PostgreSQL URL for external database. If `RUNTIME_DIR` falls back to `/tmp`, the database path adjusts accordingly. |
| `REDIS_URL` | `redis://127.0.0.1:6379/0` | No | Redis connection URL. Defaults to the in-container Redis instance. Change only if using an external Redis server. |

### Transport Modes

The `TRANSPORT` variable controls which MCP protocol the server uses. Only one transport can be active at a time. The available endpoint depends on the chosen transport:

| Transport | Endpoint | Use Case |
|---|---|---|
| `sse` (default) | `http://<host>:8000/sse/` | Persistent SSE connections. Most compatible with mcp-remote bridges. |
| `streamable-http` | `http://<host>:8000/mcp/` | HTTP-based streaming. Works with newer MCP clients that support streamable HTTP. |

**Note:** The `/mcp/` endpoint is **only** available when `TRANSPORT=streamable-http`. The `/sse/` endpoint is **only** available when `TRANSPORT=sse` (the default). These are mutually exclusive -- the server runs one transport at a time.

To switch to streamable-http:
```bash
docker run -d -e TRANSPORT=streamable-http -p 8000:8000 ne0ark/maverick-mcp:latest
```

### Writable Directory Fallback Behavior

The entrypoint checks writability of key directories and falls back automatically:

| Variable | Primary Path | Fallback Path |
|---|---|---|
| `RUNTIME_DIR` | `/config` | `/tmp/maverick-mcp` |
| `HOME` | `/config` | `$RUNTIME_DIR` or `/tmp/maverick-mcp-home` |
| `XDG_CACHE_HOME` | `/config/.cache` | `/tmp/.cache` |
| `NUMBA_CACHE_DIR` | `/config/.numba_cache` | `/tmp/.numba_cache` |

When a fallback is activated, the entrypoint logs a warning to stderr. All fallbacks are to `/tmp` which is ephemeral — data will not survive container restarts.

---

## Build-Time Variables (ARGs)

These variables are used during `docker build` and are not available at runtime. Override them with `--build-arg`.

| Variable | Default | Description |
|---|---|---|
| `MAVERICK_MCP_REF` | `main` | Git ref (branch, tag, or commit SHA) to check out and install from the upstream repository. Use a specific tag for reproducible builds: `--build-arg MAVERICK_MCP_REF=v1.2.3`. |
| `MAVERICK_MCP_REPO` | `https://github.com/wshobson/maverick-mcp.git` | Upstream Git repository URL. Change to a fork URL to build from a custom source. |
| `TA_LIB_VERSION` | `0.6.4` | TA-Lib C library source version to download and compile. Must match an available release at `https://github.com/TA-Lib/ta-lib/releases`. |

### Build Examples

```bash
# Default: tracks upstream main
docker build -t maverick-mcp .

# Pin to a specific upstream release tag
docker build --build-arg MAVERICK_MCP_REF=v1.0.0 -t maverick-mcp:v1.0.0 .

# Build from a fork
docker build \
  --build-arg MAVERICK_MCP_REPO=https://github.com/myuser/maverick-mcp.git \
  --build-arg MAVERICK_MCP_REF=my-feature-branch \
  -t maverick-mcp:custom .

# Different TA-Lib version
docker build --build-arg TA_LIB_VERSION=0.6.3 -t maverick-mcp:talib-063 .
```

---

## Upstream MaverickMCP Application Variables

These variables are consumed by the upstream [wshobson/maverick-mcp](https://github.com/wshobson/maverick-mcp) application. They can be set via `.env` file, Docker `-e` flags, or `--env-file`.

### Required API Keys

| Variable | Default | Required | Description | Get a Key |
|---|---|---|---|---|
| `TIINGO_API_KEY` | _(none)_ | **Yes** | Stock market data provider. Free tier includes 500 requests/day. Required for all stock data features. | [tiingo.com](https://tiingo.com) |

### Optional API Keys

| Variable | Default | Required | Description | Get a Key |
|---|---|---|---|---|
| `FRED_API_KEY` | _(none)_ | No | Federal Reserve Economic Data. Provides economic indicators, interest rates, and macro data. | [fred.stlouisfed.org](https://fred.stlouisfed.org/docs/api/api_key.html) |
| `OPENAI_API_KEY` | _(none)_ | No | Direct OpenAI API access. Used as a fallback AI provider for research features. | [platform.openai.com](https://platform.openai.com) |
| `ANTHROPIC_API_KEY` | _(none)_ | No | Direct Anthropic API access. Used as a fallback AI provider. | [console.anthropic.com](https://console.anthropic.com) |
| `OPENROUTER_API_KEY` | _(none)_ | No | Access to 400+ AI models via OpenRouter with intelligent cost optimization (40-60% savings). **Strongly recommended** for deep research features. | [openrouter.ai](https://openrouter.ai) |
| `EXA_API_KEY` | _(none)_ | No | Web search API for deep research agent. Provides comprehensive web content for analysis. Free tier available. | [exa.ai](https://exa.ai) |
| `TAVILY_API_KEY` | _(none)_ | No | Alternative web search provider. Can be used alongside or instead of Exa. Free tier available. | [tavily.com](https://tavily.com) |

### Application Settings

| Variable | Default | Required | Description |
|---|---|---|---|
| `APP_NAME` | `MaverickMCP` | No | Application display name. |
| `ENVIRONMENT` | `production` | No | Application environment. Set to `development` for verbose logging. |
| `LOG_LEVEL` | `info` | No | Logging verbosity. Options: `debug`, `info`, `warning`, `error`. |
| `API_VERSION` | `v1` | No | API version prefix. |
| `API_HOST` | `0.0.0.0` | No | Server bind address. Override to `127.0.0.1` to restrict to localhost. |
| `API_PORT` | `8000` | No | Server bind port. In the Docker image, this is controlled by the `PORT` variable. |
| `API_DEBUG` | `false` | No | Enable debug mode. Set to `true` only in development. |
| `MAINTENANCE_MODE` | `false` | No | Enable maintenance mode to temporarily disable the service. |

### Database Configuration

| Variable | Default | Required | Description |
|---|---|---|---|
| `DATABASE_URL` | `sqlite:///maverick_mcp.db` | No | Database connection string. SQLite (default) or PostgreSQL. The Docker entrypoint overrides this to `sqlite:///${RUNTIME_DIR}/maverick_mcp.db`. |

**SQLite (default):**
```
DATABASE_URL=sqlite:///maverick_mcp.db
```

**PostgreSQL (external):**
```
DATABASE_URL=postgresql://user:password@host:5432/maverick_mcp
```

### Redis Configuration

| Variable | Default | Required | Description |
|---|---|---|---|
| `REDIS_HOST` | `localhost` | No | Redis server hostname. In the Docker image, Redis runs inside the container. |
| `REDIS_PORT` | `6379` | No | Redis server port. |
| `REDIS_DB` | `0` | No | Redis database number. |
| `REDIS_PASSWORD` | _(empty)_ | No | Redis authentication password. Not needed for the in-container Redis. |
| `REDIS_SSL` | `false` | No | Enable SSL for Redis connections. |
| `REDIS_URL` | `redis://127.0.0.1:6379/0` | No | Full Redis connection URL. The Docker entrypoint sets this automatically. |

### Cache Configuration

| Variable | Default | Required | Description |
|---|---|---|---|
| `CACHE_ENABLED` | `true` | No | Enable/disable caching globally. |
| `CACHE_TTL_SECONDS` | `604800` | No | Cache time-to-live in seconds. Default is 7 days (604800 = 7 × 24 × 3600). |

### CORS Configuration

| Variable | Default | Required | Description |
|---|---|---|---|
| `ALLOWED_ORIGINS` | `http://localhost:3000,http://localhost:3001` | No | Comma-separated list of allowed CORS origins. Adjust for your network. |

### Data Provider Settings

| Variable | Default | Required | Description |
|---|---|---|---|
| `DATA_PROVIDER_USE_CACHE` | `true` | No | Enable caching for data provider responses. |
| `DATA_PROVIDER_CACHE_DIR` | `/tmp/maverick_mcp/cache` | No | Directory for data provider cache files. |
| `DATA_PROVIDER_CACHE_EXPIRY` | `86400` | No | Cache expiry time in seconds (default: 24 hours). |
| `DATA_PROVIDER_RATE_LIMIT` | `5` | No | Rate limit for data provider API calls. |
| `YFINANCE_TIMEOUT_SECONDS` | `30` | No | Timeout for Yahoo Finance API requests. |

### Rate Limiting

| Variable | Default | Required | Description |
|---|---|---|---|
| `RATE_LIMIT_PER_IP` | `100` | No | Maximum requests per IP per minute. |

### Monitoring

| Variable | Default | Required | Description |
|---|---|---|---|
| `SENTRY_DSN` | _(none)_ | No | Sentry DSN for error tracking. Optional, for production monitoring. |

---

## Complete `.env` Example

```env
# ============================================================
# MaverickMCP Docker — Complete Environment Configuration
# ============================================================
# Copy to /mnt/user/appdata/maverick-mcp/.env (Unraid)
# or mount as ./appdata/maverick-mcp/.env (Docker Compose)
# ============================================================

# --- Required API Keys ---
TIINGO_API_KEY=your_tiingo_api_key_here

# --- Optional API Keys ---
FRED_API_KEY=your_fred_api_key_here
OPENAI_API_KEY=your_openai_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here
OPENROUTER_API_KEY=your_openrouter_api_key_here
EXA_API_KEY=your_exa_api_key_here
TAVILY_API_KEY=your_tavily_api_key_here

# --- Application ---
APP_NAME=MaverickMCP
ENVIRONMENT=production
LOG_LEVEL=info
API_HOST=0.0.0.0
API_PORT=8000

# --- Database ---
# Default: SQLite (auto-configured by Docker entrypoint)
# For PostgreSQL: DATABASE_URL=postgresql://user:pass@host:5432/maverick_mcp

# --- Cache ---
CACHE_ENABLED=true
CACHE_TTL_SECONDS=604800

# --- Redis (auto-started inside container) ---
REDIS_ENABLED=true
ENABLE_REDIS_CACHE=true
USE_REDIS_CACHE=true
# REDIS_URL=redis://127.0.0.1:6379/0

# --- Container Infrastructure ---
# PORT=8000
# RUNTIME_DIR=/config
# ENV_FILE=/config/.env
# HOME=/config
# XDG_CACHE_HOME=/config/.cache
# NUMBA_CACHE_DIR=/config/.numba_cache
# UMASK=002
```

---

## Variable Priority Order

When the same variable is set in multiple places, the effective value is determined by this priority (highest first):

1. **Docker `-e` flag** or `--env-file` — overrides everything
2. **Container image `ENV`** — set in Dockerfile
3. **Entrypoint `.env` file** — loaded by `docker-entrypoint.sh`
4. **Application defaults** — hardcoded in the upstream application

The entrypoint only sets a variable from `.env` if it is not already set in the environment. This means Docker-level variables always take precedence over `.env` file values.
