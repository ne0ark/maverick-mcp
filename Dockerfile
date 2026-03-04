FROM python:3.12-slim

LABEL org.opencontainers.image.title="maverick-mcp" \
      org.opencontainers.image.description="Container image for the Maverick MCP server" \
      org.opencontainers.image.source="https://github.com/wshobson/maverick-mcp"

ARG MAVERICK_MCP_REF=main
ARG TA_LIB_VERSION=0.6.4

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    ENV_FILE="/config/.env" \
    PORT=8000 \
    UV_CACHE_DIR=/tmp/uv-cache

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        tini \
    && curl -fsSL "https://github.com/TA-Lib/ta-lib/releases/download/v${TA_LIB_VERSION}/ta-lib-${TA_LIB_VERSION}-src.tar.gz" -o /tmp/ta-lib.tgz \
    && tar -tzf /tmp/ta-lib.tgz >/dev/null \
    && tar -xzf /tmp/ta-lib.tgz -C /tmp \
    && cd "/tmp/ta-lib-${TA_LIB_VERSION}" \
    && ./configure --prefix=/usr \
    && make \
    && make install \
    && rm -rf /tmp/ta-lib.tgz "/tmp/ta-lib-${TA_LIB_VERSION}" \
    && apt-get purge -y --auto-remove build-essential curl \
    && rm -rf /var/lib/apt/lists/*

# Install directly from upstream so the image always tracks the requested ref/tag.
RUN pip install --upgrade pip \
    && pip install uv \
    && pip install "git+https://github.com/wshobson/maverick-mcp.git@${MAVERICK_MCP_REF}"

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Unraid-friendly writable app dir.
RUN useradd --create-home --home-dir /config --shell /usr/sbin/nologin mcp
USER mcp
WORKDIR /config

# Default MCP HTTP/SSE port used by most Unraid templates.
EXPOSE 8000

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["sh", "-c", "exec uv run python -m maverick_mcp.api.server --transport sse --host 0.0.0.0 --port ${PORT:-8000}"]
