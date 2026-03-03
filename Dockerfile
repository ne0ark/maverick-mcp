FROM python:3.12-slim

LABEL org.opencontainers.image.title="maverick-mcp" \
      org.opencontainers.image.description="Container image for the Maverick MCP server" \
      org.opencontainers.image.source="https://github.com/wshobson/maverick-mcp"

ARG MAVERICK_MCP_REF=main

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    MCP_COMMAND="maverick-mcp"

RUN apt-get update \
    && apt-get install -y --no-install-recommends git tini \
    && rm -rf /var/lib/apt/lists/*

# Install directly from upstream so the image always tracks the requested ref/tag.
RUN pip install --upgrade pip \
    && pip install "git+https://github.com/wshobson/maverick-mcp.git@${MAVERICK_MCP_REF}"

# Unraid-friendly writable app dir.
RUN useradd --create-home --home-dir /config --shell /usr/sbin/nologin mcp
USER mcp
WORKDIR /config

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["sh", "-c", "${MCP_COMMAND}"]
