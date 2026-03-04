#!/bin/sh
set -eu

umask "${UMASK:-002}"

: "${REDIS_ENABLED:=true}"
: "${ENABLE_REDIS_CACHE:=true}"
: "${USE_REDIS_CACHE:=true}"
export REDIS_ENABLED ENABLE_REDIS_CACHE USE_REDIS_CACHE

runtime_dir="${RUNTIME_DIR:-/config}"
if [ ! -d "${runtime_dir}" ]; then
  mkdir -p "${runtime_dir}" 2>/dev/null || true
fi

if [ ! -w "${runtime_dir}" ]; then
  fallback_runtime_dir="/tmp/maverick-mcp"
  mkdir -p "${fallback_runtime_dir}"
  runtime_dir="${fallback_runtime_dir}"
  echo "Runtime directory ${RUNTIME_DIR:-/config} is not writable for $(id -u):$(id -g); using ${runtime_dir}" >&2
fi

cd "${runtime_dir}"

env_file="/config/.env"

numba_cache_dir="${NUMBA_CACHE_DIR:-${runtime_dir}/.numba_cache}"
if ! mkdir -p "${numba_cache_dir}" 2>/dev/null; then
  fallback_numba_cache_dir="/tmp/.numba_cache"
  mkdir -p "${fallback_numba_cache_dir}"
  numba_cache_dir="${fallback_numba_cache_dir}"
  echo "NUMBA cache path ${NUMBA_CACHE_DIR:-${runtime_dir}/.numba_cache} is not writable; using ${fallback_numba_cache_dir}" >&2
fi
export NUMBA_CACHE_DIR="${numba_cache_dir}"

if [ -z "${DATABASE_URL:-}" ]; then
  export DATABASE_URL="sqlite:///${runtime_dir}/maverick_mcp.db"
fi

mkdir -p "${runtime_dir}/logs" "${runtime_dir}/redis" 2>/dev/null || true

if [ -f "${env_file}" ]; then
  echo "Loading environment from ${env_file}"
  set -a
  # shellcheck disable=SC1090
  . "${env_file}"
  set +a
else
  echo "No env file found at ${env_file}; set TIINGO_API_KEY via .env or Docker env vars." >&2
fi

if [ "${REDIS_ENABLED}" = "true" ] || [ "${ENABLE_REDIS_CACHE}" = "true" ] || [ "${USE_REDIS_CACHE}" = "true" ]; then
  : "${REDIS_URL:=redis://127.0.0.1:6379/0}"
  export REDIS_URL

  if ! redis-cli -h 127.0.0.1 -p 6379 ping >/dev/null 2>&1; then
    redis-server \
      --bind 127.0.0.1 \
      --port 6379 \
      --dir "${runtime_dir}/redis" \
      --save "" \
      --appendonly no \
      --daemonize yes >/dev/null 2>&1 || true
  fi
fi

exec "$@"
