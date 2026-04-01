# Maverick MCP — Docker / Unraid Deployment

[![Docker Image](https://img.shields.io/docker/image-size/ne0ark/maverick-mcp/latest?label=docker%20image)](https://hub.docker.com/r/ne0ark/maverick-mcp)
[![Upstream](https://img.shields.io/github/stars/wshobson/maverick-mcp?label=upstream%20%E2%98%85&style=social)](https://github.com/wshobson/maverick-mcp)

Containerized build of **[wshobson/maverick-mcp](https://github.com/wshobson/maverick-mcp)** — a personal stock analysis MCP server with TA-Lib, VectorBT, and built-in Redis, packaged for Unraid NAS and generic Docker deployments.

---

## Overview

This project wraps the upstream [wshobson/maverick-mcp](https://github.com/wshobson/maverick-mcp) (MIT License) into a ready-to-run Docker image. The upstream project provides 39+ financial analysis tools including technical indicators, stock screening, backtesting, and portfolio optimization, all accessible via MCP (Model Context Protocol).

**What this image adds on top of upstream:**

| Feature | Detail |
|---|---|
| TA-Lib C library | v0.6.4 compiled from source |
| VectorBT | Pre-installed for backtesting support |
| Built-in Redis | Starts automatically inside the container |
| SQLite fallback | Default database; no external Postgres required |
| Unraid-friendly user | Runs as `UID:GID 99:100` (`nobody:users`) |
| `.env` auto-loading | Entrypoint discovers and loads your config file |
| Writable cache handling | Graceful fallbacks for `/config`, `$HOME`, `$XDG_CACHE_HOME` |

---

## Quick Start

### Docker Run

```bash
docker run -d \
  --name maverick-mcp \
  -p 8000:8000 \
  -v /path/to/appdata/maverick-mcp:/config \
  -e TIINGO_API_KEY=your_tiingo_key \
  ne0ark/maverick-mcp:latest
```

### Docker Compose

```yaml
services:
  maverick-mcp:
    image: ne0ark/maverick-mcp:latest
    container_name: maverick-mcp
    ports:
      - "8000:8000"
    volumes:
      - ./appdata/maverick-mcp:/config
    env_file:
      - ./appdata/maverick-mcp/.env
    restart: unless-stopped
```

> **Note:** The image is also available on GitHub Container Registry as `ghcr.io/ne0ark/maverick-mcp:latest`.

The SSE endpoint will be available at `http://<host>:8000/sse/`.

---

## Unraid Template Installation

### Step-by-step

1. **Install Community Applications** (if not already installed) from the Unraid Apps tab.

2. **Add the template repository:**
   - Go to **Apps → Settings → Template repositories**
   - Add: `https://github.com/ne0ark/maverick-mcp`

3. **Search for "maverick-mcp"** in the Apps tab and click **Install**.

4. **Configure the container:**

   | Field | Value |
   |---|---|
   | **Repository** | `ne0ark/maverick-mcp:latest` |
   | **Network Type** | `bridge` |
   | **Console shell** | `bash` (optional, for debugging) |

5. **Map the config path:**

   | Container Path | Host Path |
   |---|---|
   | `/config` | `/mnt/user/appdata/maverick-mcp` |

6. **Map the port:**

   | Container Port | Host Port | Protocol |
   |---|---|---|
   | `8000` | `8000` (or your preferred port) | TCP |

7. **Add Extra Parameters** (recommended):
   ```
   --env-file=/mnt/user/appdata/maverick-mcp/.env
   ```

8. **Create your `.env` file** at `/mnt/user/appdata/maverick-mcp/.env` (see [.env File Setup](#env-file-setup) below).

9. **Set file permissions** so the container user (99:100) can read it:
   ```bash
   chmod 640 /mnt/user/appdata/maverick-mcp/.env
   chown nobody:users /mnt/user/appdata/maverick-mcp/.env
   ```

10. Click **Apply** and start the container.

### Manual Template (no Community Apps)

If you prefer to add the container manually:

1. Go to **Docker → Add Container**
2. Set **Repository** to `ne0ark/maverick-mcp:latest`
3. Set **Network Type** to `bridge`
4. Add path mapping: `/config` → `/mnt/user/appdata/maverick-mcp`
5. Add port mapping: `8000` → `8000` (TCP)
6. Add any required environment variables or an `--env-file` in Extra Parameters

---

## Environment Variables

### Container Infrastructure Variables

| Variable | Default | Required | Description |
|---|---|---|---|
| `HOME` | `/config` | No | Home directory for Python libraries that derive cache paths from `$HOME`. |
| `XDG_CACHE_HOME` | `/config/.cache` | No | Base cache directory for libraries like yfinance. |
| `NUMBA_CACHE_DIR` | `/config/.numba_cache` | No | Cache directory for Numba/pandas-ta JIT compilation. |
| `UMASK` | `002` | No | Process umask for group-writable files on Unraid shares. |
| `PORT` | `8000` | No | Port variable for compatibility; the default CMD binds port 8000. |
| `RUNTIME_DIR` | `/config` | No | Working directory for runtime writes (SQLite DB, logs). |
| `ENV_FILE` | `/config/.env` | No | Path to `.env` file loaded by the entrypoint. |
| `UV_CACHE_DIR` | `/tmp/uv-cache` | No | Cache directory for the `uv` package manager. |
| `REDIS_ENABLED` | `true` | No | Enables built-in Redis startup and cache integration. |
| `ENABLE_REDIS_CACHE` | `true` | No | Compatibility toggle for upstream Redis cache integration. |
| `USE_REDIS_CACHE` | `true` | No | Compatibility toggle for upstream Redis cache integration. |
| `DATABASE_URL` | `sqlite:///${RUNTIME_DIR}/maverick_mcp.db` | No | Database connection string. Defaults to SQLite in the runtime directory. |
| `REDIS_URL` | `redis://127.0.0.1:6379/0` | No | Redis connection URL. Points to the in-container Redis instance. |

### Build-Time Variables (for custom builds)

| Variable | Default | Description |
|---|---|---|
| `MAVERICK_MCP_REF` | `main` | Git ref (branch/tag/commit) to build from upstream. |
| `MAVERICK_MCP_REPO` | `https://github.com/wshobson/maverick-mcp.git` | Upstream repository URL. |
| `TA_LIB_VERSION` | `0.6.4` | TA-Lib C library version to compile. |

### Upstream MaverickMCP API Keys

| Variable | Required | Description |
|---|---|---|
| `TIINGO_API_KEY` | **Yes** | Stock data provider. Free tier (500 req/day) at [tiingo.com](https://tiingo.com). |
| `FRED_API_KEY` | No | Federal Reserve economic data. |
| `OPENAI_API_KEY` | No | Direct OpenAI access (fallback). |
| `ANTHROPIC_API_KEY` | No | Direct Anthropic access (fallback). |
| `OPENROUTER_API_KEY` | No | Access to 400+ AI models with cost optimization (recommended for research). |
| `EXA_API_KEY` | No | Web search for deep research. Free tier at [exa.ai](https://exa.ai). |
| `TAVILY_API_KEY` | No | Alternative web search provider. Free tier at [tavily.com](https://tavily.com). |

### Upstream Application Settings

| Variable | Default | Description |
|---|---|---|
| `ENVIRONMENT` | `production` | Application environment (`development` / `production`). |
| `LOG_LEVEL` | `info` | Logging verbosity (`debug`, `info`, `warning`, `error`). |
| `CACHE_ENABLED` | `true` | Enable/disable caching. |
| `CACHE_TTL_SECONDS` | `604800` | Cache time-to-live (7 days default). |
| `API_HOST` | `0.0.0.0` | Server bind address. |
| `API_PORT` | `8000` | Server bind port (set by container `PORT` env). |

---

## Path Mappings

| Container Path | Host Path (Unraid) | Purpose |
|---|---|---|
| `/config` | `/mnt/user/appdata/maverick-mcp` | Working directory, `.env` file, SQLite DB, logs, cache |

The `/config` path is the single mount point you need. It stores:

- `.env` — your configuration file
- `maverick_mcp.db` — SQLite database (default)
- `logs/` — application logs
- `redis/` — Redis data directory
- `.cache/` — library cache (yfinance, etc.)
- `.numba_cache/` — Numba JIT cache

---

## Port Mappings

| Container Port | Default Host Port | Protocol | Purpose |
|---|---|---|---|
| `8000` | `8000` | TCP | MCP SSE/HTTP server endpoint |

The server exposes these endpoints:

| Endpoint | URL |
|---|---|
| SSE transport | `http://<host>:8000/sse/` |
| HTTP transport | `http://<host>:8000/mcp/` |
| Health check | `http://<host>:8000/health` |

> **Note:** The trailing slash on `/sse/` is **required** — a 307 redirect from `/sse` to `/sse/` will break tool registration in Claude Desktop.

---

## .env File Setup

The entrypoint automatically loads a `.env` file from the first readable path it finds, in this order:

1. `$ENV_FILE` (default: `/config/.env`)
2. `$RUNTIME_DIR/.env` (default: `/config/.env`)
3. `/config/.env`
4. `/workspace/.env`

### Example `.env`

```env
# Required
TIINGO_API_KEY=your_tiingo_api_key_here

# Optional — Economic data
FRED_API_KEY=your_fred_api_key_here

# Optional — AI research (recommended)
OPENROUTER_API_KEY=your_openrouter_api_key_here
EXA_API_KEY=your_exa_api_key_here
TAVILY_API_KEY=your_tavily_api_key_here

# Optional — Direct AI provider access
OPENAI_API_KEY=your_openai_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# Application settings
ENVIRONMENT=production
LOG_LEVEL=info
CACHE_ENABLED=true
CACHE_TTL_SECONDS=604800
```

### Unraid placement

Place the file at:
```
/mnt/user/appdata/maverick-mcp/.env
```

Then ensure permissions:
```bash
chown nobody:users /mnt/user/appdata/maverick-mcp/.env
chmod 640 /mnt/user/appdata/maverick-mcp/.env
```

The container runs as UID 99 (nobody), so the file must be readable by that user.

---

## Redis Configuration

The image includes a built-in Redis server that starts automatically when any of these variables are `true` (they all default to `true`):

- `REDIS_ENABLED=true`
- `ENABLE_REDIS_CACHE=true`
- `USE_REDIS_CACHE=true`

Redis runs on `127.0.0.1:6379` inside the container — no external Redis container needed. Data is stored at `${RUNTIME_DIR}/redis/` (in-memory mode, no persistence).

To disable Redis and use in-memory caching only:
```bash
docker run -d \
  -e REDIS_ENABLED=false \
  -e ENABLE_REDIS_CACHE=false \
  -e USE_REDIS_CACHE=false \
  ...
```

---

## Troubleshooting

### VectorBT Warning on Startup

If you see `Backtesting module not available - VectorBT may not be installed`:

- This typically means you are running an **older image tag** that predates the VectorBT install step.
- **Fix:** Pull the latest image (`docker pull ne0ark/maverick-mcp:latest`) and recreate the container.

### Cache Path Errors / Permission Denied

The entrypoint checks writability of `/config`, `$HOME`, `$XDG_CACHE_HOME`, and `NUMBA_CACHE_DIR`. If any are not writable by UID 99, it falls back to `/tmp/` paths automatically.

If you see fallback messages in logs:
```
Runtime directory /config is not writable for 99:100; using /tmp/maverick-mcp
```
Check that your Unraid volume mapping has correct permissions:
```bash
chown -R nobody:users /mnt/user/appdata/maverick-mcp
```

### `.env` File Not Loading

If the entrypoint reports:
```
No readable .env file found (checked: /config/.env, /config/.env, /config/.env, /workspace/.env)
```

- Verify the file exists at the mapped host path: `ls -la /mnt/user/appdata/maverick-mcp/.env`
- Verify it's readable by UID 99: `sudo -u nobody cat /mnt/user/appdata/maverick-mcp/.env`
- Check for Windows-style line endings (`\r\n`). Convert with: `sed -i 's/\r$//' /mnt/user/appdata/maverick-mcp/.env`
- Alternatively, pass env vars directly via Docker `-e` flags or `--env-file` in Extra Parameters.

### Redis Fails to Start

- Check container logs: `docker logs maverick-mcp`
- Ensure the Redis data directory is writable: the entrypoint creates `${RUNTIME_DIR}/redis/`
- Redis is started in daemon mode; if it fails, the MCP server continues without caching

### Connection Refused from Claude Desktop

- Ensure you use the trailing slash: `http://<host-ip>:8000/sse/`
- Verify the container is running: `docker ps | grep maverick`
- Check firewall rules allow port 8000
- Use the host's LAN IP (not `localhost`) if Claude Desktop runs on a different machine

---

## Building from Source

```bash
git clone https://github.com/ne0ark/maverick-mcp.git
cd maverick-mcp

# Build with defaults (tracks upstream main branch)
docker build -t maverick-mcp .

# Build a specific upstream ref
docker build \
  --build-arg MAVERICK_MCP_REF=v1.2.3 \
  -t maverick-mcp:v1.2.3 .

# Build with a different TA-Lib version
docker build \
  --build-arg TA_LIB_VERSION=0.6.3 \
  -t maverick-mcp:talib-063 .
```

### Multi-architecture build

```bash
docker buildx build \
  --platform linux/amd64 \
  -t maverick-mcp:latest \
  --push \
  .
```

---

## Connecting to MCP Clients

### Claude Desktop

```json
{
  "mcpServers": {
    "maverick-mcp": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://<host-ip>:8000/sse/"]
    }
  }
}
```

### Cursor / Windsurf IDE (direct SSE)

```json
{
  "mcpServers": {
    "maverick-mcp": {
      "url": "http://<host-ip>:8000/sse/"
    }
  }
}
```

### Claude Code CLI

```bash
claude mcp add --transport sse maverick-mcp http://<host-ip>:8000/sse/
```

---

## Upstream Project Info

| | |
|---|---|
| **Upstream repo** | [wshobson/maverick-mcp](https://github.com/wshobson/maverick-mcp) |
| **Docker image** | [ne0ark/maverick-mcp](https://hub.docker.com/r/ne0ark/maverick-mcp) on Docker Hub |
| **License** | MIT (same as upstream) |
| **Python** | 3.12-slim |
| **Transport** | SSE on port 8000 |
| **Stars** | 465+ (upstream) |

### Upstream Features

- 39+ financial analysis tools (technical indicators, screening, portfolio optimization)
- Pre-seeded S&P 500 database (520 stocks)
- VectorBT-powered backtesting with 15+ strategies
- AI-powered deep research agents
- Redis caching with in-memory fallback
- SQLite default with PostgreSQL option

---

## License

This Docker packaging project follows the same [MIT License](https://github.com/wshobson/maverick-mcp/blob/master/LICENSE) as the upstream project.

---

## Disclaimer

<sub>This software is for educational and informational purposes only. It is **NOT** financial advice. Past performance does not guarantee future results. All investments carry risk of loss. Always consult a qualified financial advisor before making investment decisions.</sub>
