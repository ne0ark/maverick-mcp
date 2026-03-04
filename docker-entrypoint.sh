#!/bin/sh
set -eu

umask "${UMASK:-002}"

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

mkdir -p "${runtime_dir}/logs" 2>/dev/null || true

if [ -f "${ENV_FILE:-/config/.env}" ]; then
  echo "Loading environment from ${ENV_FILE:-/config/.env}"
  set -a
  # shellcheck disable=SC1090
  . "${ENV_FILE:-/config/.env}"
  set +a
fi

exec "$@"
