# UNRAID Docker Variables for `maverick-mcp`

This file documents recommended Unraid template variables for running the
`maverick-mcp` container.

## Container behavior summary

- The image runs as non-root user `mcp`.
- `/config` is the container working directory and should be mapped to appdata.
- Entrypoint (under `tini`) loads `${ENV_FILE}` (default `/config/.env`) when present, then executes container `CMD`.
- Startup command is controlled by `MCP_COMMAND`.
- Dockerfile installs TA-Lib (Linux native dependency) and exposes TCP `8000` by default for HTTP/SSE style deployment.

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
| `MCP_COMMAND` | `maverick-mcp` | No | Default command used by `CMD` (`sh -c ${MCP_COMMAND}`). |
| `ENV_FILE` | `/config/.env` | No | In-container `.env` file path loaded by entrypoint when file exists. |
| `PORT` | `8000` | Recommended | Service port value used by your runtime command/application config. |

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

2. Built-in entrypoint `.env` loading via `ENV_FILE=/config/.env` (default).

Use `.env.example` from the upstream project as the source of keys and values,
then place your filled file at that Unraid path.

## Port forwarding (must be defined in Docker/Unraid)

The image includes `EXPOSE 8000`, and Unraid should map host/container ports for
HTTP/SSE deployments.

| Container Port | Host Port (example) | Protocol | Required |
|---|---|---|---:|
| `8000` (or `${PORT}`) | `8000` (or custom like `18000`) | TCP | Yes (for HTTP/SSE access) |

Example mapping when `PORT=8000`:

- Container Port: `8000`
- Host Port: `8000` (or another free port like `18000`)

## Maintainer notes

1. Keep `/config` mapped and writable.
2. Keep `.env` persisted in Unraid appdata path (not ephemeral container FS).
3. Keep Unraid port mapping aligned with `PORT`.
4. Keep `EXPOSE` and docs aligned if default port changes.
