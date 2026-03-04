# UNRAID Docker Variables for `maverick-mcp`

This file documents recommended Unraid template variables for running the
`maverick-mcp` container.

## Container behavior summary

- The image runs as non-root `UID:GID 99:100` (`nobody:users` on Unraid).
- `/config` is the container working directory and should be mapped to appdata.
- Entrypoint (under `tini`) loads `.env` from `${ENV_FILE}` (default `/config/.env`) with fallback checks, then executes container `CMD` from `${RUNTIME_DIR}`.
- Entrypoint applies `${UMASK}` (default `002`) for Unraid-friendly file permissions.
- Default command runs the upstream SSE server via:
  `uv run python -m maverick_mcp.api.server --transport sse --host 0.0.0.0 --port 8000`.
- Dockerfile installs TA-Lib and `vectorbt` dependencies, and exposes TCP `8000` by default for HTTP/SSE deployment.
- TA-Lib C library build defaults to `0.6.4` (via `TA_LIB_VERSION` build arg), which is the recommended upstream release line for current builds.

## Unraid template fields

| Unraid Field | Value / Example | Required | Description |
|---|---|---:|---|
| Repository | `ghcr.io/<your-namespace>/maverick-mcp:latest` | Yes | Image to run. |
| Network Type | `bridge` | Yes | Use bridge so explicit port mapping is visible/manageable. |
| Console shell command | `bash` | No | Convenience only. |
| Extra Parameters | `--env-file=/mnt/user/appdata/maverick-mcp/.env` | Recommended | Docker-level env injection from Unraid host path. |

## Environment variables

| Key | Default | Required | Description |
|---|---|---:|---|
| `NUMBA_CACHE_DIR` | `/config/.numba_cache` | No | Writable cache directory used by Numba/pandas-ta to avoid JIT cache errors on read-only site-packages. |
| `UMASK` | `002` | No | Process umask applied at startup for group-writable files on Unraid shares. |
| `PORT` | `8000` | Optional | Kept for compatibility with existing `.env` files; default CMD currently binds fixed port `8000`. |
| `RUNTIME_DIR` | `/config` | No | Working directory used for runtime writes (SQLite DB and logs when app uses relative paths). |
| `ENV_FILE` | `/config/.env` | No | Preferred `.env` path read by entrypoint before startup initialization. |
| `REDIS_ENABLED` | `true` | No | Enables built-in Redis startup and Redis cache integration by default. |
| `ENABLE_REDIS_CACHE` | `true` | No | Compatibility toggle kept enabled so upstream cache integration uses Redis. |
| `USE_REDIS_CACHE` | `true` | No | Compatibility toggle kept enabled so upstream cache integration uses Redis. |

## Path mappings

| Container Path | Host Path (example) | Required | Purpose |
|---|---|---:|---|
| `/config` | `/mnt/user/appdata/maverick-mcp` | Yes | Writable working directory for container user and location for persisted `.env`. |

## `.env` file location (Unraid PATH requirement)


Store the environment file on the Unraid host path mapped for this container,
for example:

- Host file path: `/mnt/user/appdata/maverick-mcp/.env`
- Container-visible path (via `/config` mapping): `/config/.env`

You can load environment values either way:

1. Unraid Extra Parameters with Docker `--env-file`:

   ```text
   --env-file=/mnt/user/appdata/maverick-mcp/.env
   ```

2. Built-in entrypoint `.env` loading from `${ENV_FILE}` (default `/config/.env`). If the file is absent, entrypoint also checks `/workspace/.env` before proceeding with Docker-provided env vars only.

> The container does **not** generate `.env` automatically.
> Use the downloaded project's `.env.example` and create your own host `.env` at
> `/mnt/user/appdata/maverick-mcp/.env` so it appears in the container at `/config/.env`.

If `/config` is not writable for the container user (`99:100`), entrypoint falls back to
`/tmp/maverick-mcp` as runtime directory and `/tmp/.numba_cache` for Numba cache writes.
In that fallback mode, `DATABASE_URL` defaults to `sqlite:////tmp/maverick-mcp/maverick_mcp.db`.

## TA-Lib version note

- Current image default: `TA_LIB_VERSION=0.6.4`.
- This traceback pattern (`pandas_ta` -> `numba` cache locator error) is not a
  TA-Lib C version mismatch; it is a cache-path/writeability issue.

## Redis/SQLite runtime defaults

- SQLite is enabled by default through `DATABASE_URL` fallback to a local file in `${RUNTIME_DIR}`.
- Redis is started in-container by entrypoint (127.0.0.1:6379) when Redis toggles are enabled (default).
- `REDIS_URL` defaults to `redis://127.0.0.1:6379/0` if unset.

Use `.env.example` from the downloaded upstream project as the source of keys and values,
then place your filled file at that Unraid path.

## Port forwarding (must be defined in Docker/Unraid)

The image includes `EXPOSE 8000`, and default container `CMD` serves on
container port `8000`.

| Container Port | Host Port (example) | Protocol | Required |
|---|---|---|---:|
| `8000` | `8000` (or custom like `18000`) | TCP | Yes (for HTTP/SSE access) |

Example mapping:

- Container Port: `8000`
- Host Port: `8000` (or another free port like `18000`)

## Maintainer notes

1. Keep `/config` mapped and writable.
2. Keep `.env` persisted in Unraid appdata path (not ephemeral container FS).
3. Keep Unraid port mapping aligned with container `CMD` port.
4. Keep `EXPOSE` and docs aligned if default port changes.
