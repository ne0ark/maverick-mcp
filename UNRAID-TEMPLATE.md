# Unraid Template Guide — maverick-mcp

Detailed guide for deploying the `ne0ark/maverick-mcp` container on Unraid using the built-in Docker management UI or Community Apps.

---

## Template XML Fields

When adding the container via Unraid's Docker UI, use these values:

| Unraid Field | Value | Required |
|---|---|---|
| **Name** | `maverick-mcp` | Yes |
| **Repository** | `ne0ark/maverick-mcp:latest` | Yes |
| **Network Type** | `bridge` | Yes |
| **Console shell command** | `bash` | No |

### Extra Parameters (recommended)

Add this to **Extra Parameters** to inject environment variables from your `.env` file at the Docker level:

```
--env-file=/mnt/user/appdata/maverick-mcp/.env
```

This is a secondary loading mechanism. The container entrypoint also loads `/config/.env` automatically, so both methods work. Using `--env-file` ensures Docker itself sees the variables.

---

## Step-by-Step Unraid Setup

### Method 1: Community Apps (recommended)

1. Open the **Apps** tab in the Unraid webGUI.
2. Search for **"maverick-mcp"**.
3. Click **Install**.
4. Configure the fields as described below.
5. Click **Apply**.

### Method 2: Manual Container Addition

1. Go to **Docker** tab → **Add Container**.
2. Switch to **Advanced View** (toggle in the top right).
3. Fill in the fields per the table above.

---

## Path Mapping

| Container Path | Host Path | Access Mode | Purpose |
|---|---|---|---|
| `/config` | `/mnt/user/appdata/maverick-mcp` | Read/Write | All persistent data: `.env`, SQLite DB, logs, cache, Redis data |

### What gets stored under `/config`

```
/mnt/user/appdata/maverick-mcp/
├── .env                  # Your API keys and configuration
├── maverick_mcp.db       # SQLite database (default)
├── logs/                 # Application logs
├── redis/                # Redis data directory
├── .cache/               # Library cache (yfinance, etc.)
└── .numba_cache/         # Numba JIT compilation cache
```

### Creating the appdata directory

```bash
mkdir -p /mnt/user/appdata/maverick-mcp
```

Unraid typically creates this automatically when you add the path mapping, but creating it ahead of time lets you place the `.env` file before the first start.

---

## Port Mapping

| Container Port | Host Port | Protocol | Purpose |
|---|---|---|---|
| `8000` | `8000` | TCP | MCP SSE/HTTP server |

- Use `bridge` network type so the port mapping is explicit and visible in the Unraid Docker UI.
- You can change the host port to any free port (e.g., `18000:8000`) if `8000` is already in use.

---

## Environment Variables (Unraid UI)

In the Unraid Docker template, add these as **Variable** entries:

### Minimum Required

| Key | Value | Description |
|---|---|---|
| `TIINGO_API_KEY` | `your_tiingo_key` | Free at [tiingo.com](https://tiingo.com) — required for stock data |

### Recommended

| Key | Value | Description |
|---|---|---|
| `FRED_API_KEY` | `your_fred_key` | Federal Reserve economic data |
| `OPENROUTER_API_KEY` | `your_key` | 400+ AI models, cost-optimized research |
| `EXA_API_KEY` | `your_key` | Web search for deep research |
| `LOG_LEVEL` | `info` | Logging verbosity |

### Infrastructure (pre-configured in image, override only if needed)

| Key | Default | Override When... |
|---|---|---|
| `REDIS_ENABLED` | `true` | Set to `false` to disable in-container Redis |
| `ENABLE_REDIS_CACHE` | `true` | Set to `false` to disable Redis caching |
| `USE_REDIS_CACHE` | `true` | Set to `false` to disable Redis caching |
| `DATABASE_URL` | SQLite auto-path | Set to Postgres URL for external database |
| `REDIS_URL` | `redis://127.0.0.1:6379/0` | Change only if using external Redis |

---

## `.env` File Placement and Permissions

### Location

```
/mnt/user/appdata/maverick-mcp/.env
```

This file maps to `/config/.env` inside the container, which is the first path the entrypoint checks.

### Creating the file

```bash
cat > /mnt/user/appdata/maverick-mcp/.env << 'EOF'
# Required
TIINGO_API_KEY=your_tiingo_api_key_here

# Optional
FRED_API_KEY=your_fred_key_here
OPENROUTER_API_KEY=your_openrouter_key_here
EXA_API_KEY=your_exa_key_here
TAVILY_API_KEY=your_tavily_key_here
OPENAI_API_KEY=your_openai_key_here
ANTHROPIC_API_KEY=your_anthropic_key_here

# Application
ENVIRONMENT=production
LOG_LEVEL=info
EOF
```

### Setting permissions

The container runs as **UID 99, GID 100** (`nobody:users` on Unraid). The `.env` file must be readable by this user:

```bash
chown nobody:users /mnt/user/appdata/maverick-mcp/.env
chmod 640 /mnt/user/appdata/maverick-mcp/.env
```

### Verifying the file is readable

```bash
sudo -u nobody cat /mnt/user/appdata/maverick-mcp/.env
```

If this command succeeds, the container entrypoint will be able to read it.

### Entrypoint `.env` search order

The entrypoint searches for a `.env` file in this order and uses the first readable one:

1. `$ENV_FILE` (defaults to `/config/.env`)
2. `$RUNTIME_DIR/.env` (defaults to `/config/.env`)
3. `/config/.env`
4. `/workspace/.env`

If none are found, the entrypoint proceeds using only Docker-provided environment variables and logs a warning.

---

## Common Unraid Gotchas

### File Permissions

The container runs as `99:100` (nobody:users). If `/config` is not writable, the entrypoint falls back to `/tmp/maverick-mcp` — this means your SQLite database, logs, and cache will be lost on container restart.

**Fix:** Ensure the appdata directory is writable:

```bash
chown -R nobody:users /mnt/user/appdata/maverick-mcp
chmod -R 775 /mnt/user/appdata/maverick-mcp
```

### Cache Paths Not Writable

If you see messages like:

```
XDG cache path /config/.cache is not writable; using /tmp/.cache
NUMBA cache path /config/.numba_cache is not writable; using /tmp/.numba_cache
```

The `/config` volume mapping needs correct permissions. The entrypoint handles this gracefully by falling back to `/tmp` paths, but those are ephemeral and lost on restart.

### Redis Startup

Redis is started by the entrypoint as a daemon inside the container. It binds to `127.0.0.1:6379` (localhost only, not exposed to the host network).

If Redis fails to start, the MCP server continues running but with in-memory caching only. Check logs:

```bash
docker logs maverick-mcp 2>&1 | grep -i redis
```

### Container Shows "No readable .env file found"

This means:

1. The file doesn't exist at the expected path, OR
2. The file exists but isn't readable by UID 99

Check both:

```bash
ls -la /mnt/user/appdata/maverick-mcp/.env
sudo -u nobody cat /mnt/user/appdata/maverick-mcp/.env
```

Also check for Windows-style line endings (CRLF). If the `.env` was created or edited on Windows:

```bash
sed -i 's/\r$//' /mnt/user/appdata/maverick-mcp/.env
```

### Container Port Conflicts

If port `8000` is already in use on your Unraid server, map to a different host port:

| Container Port | Host Port |
|---|---|
| `8000` | `18000` (or any free port) |

Update your MCP client connection URLs accordingly: `http://<unraid-ip>:18000/sse/` (or `/mcp/` if using `TRANSPORT=streamable-http`)

### Changing the Transport Mode

The container defaults to SSE transport (`/sse/` endpoint). To use streamable HTTP (`/mcp/` endpoint) instead, add the `TRANSPORT` environment variable:

| Variable | Value | Endpoint |
|---|---|---|
| `TRANSPORT` | `sse` (default) | `http://<host>:8000/sse/` |
| `TRANSPORT` | `streamable-http` | `http://<host>:8000/mcp/` |

These are mutually exclusive -- only one transport runs at a time.

### Image Updates

To pull the latest image:

```bash
docker pull ne0ark/maverick-mcp:latest
```

Then stop and recreate the container (your data persists in the `/config` volume mapping).

---

## Connecting from MCP Clients

Once the container is running, connect your MCP client to:

| Client | Configuration |
|---|---|
| **Claude Desktop** | `"command": "npx", "args": ["-y", "mcp-remote", "http://<unraid-ip>:8000/sse/"]` |
| **Cursor IDE** | `"url": "http://<unraid-ip>:8000/sse/"` |
| **Windsurf** | `"serverUrl": "http://<unraid-ip>:8000/sse/"` |
| **Claude Code CLI** | `claude mcp add --transport sse maverick-mcp http://<unraid-ip>:8000/sse/` |

Replace `<unraid-ip>` with your Unraid server's LAN IP address (e.g., `192.168.1.100`).

> **Important:** Always include the trailing slash in `/sse/` — omitting it causes a 307 redirect that breaks tool registration.
