#!/bin/sh
set -eu

numba_cache_dir="${NUMBA_CACHE_DIR:-/config/.numba_cache}"
if ! mkdir -p "${numba_cache_dir}" 2>/dev/null; then
  fallback_numba_cache_dir="/tmp/.numba_cache"
  mkdir -p "${fallback_numba_cache_dir}"
  export NUMBA_CACHE_DIR="${fallback_numba_cache_dir}"
  echo "NUMBA cache path ${numba_cache_dir} is not writable; using ${fallback_numba_cache_dir}" >&2
fi

if [ -f "${ENV_FILE:-/config/.env}" ]; then
  echo "Loading environment from ${ENV_FILE:-/config/.env}"
  set -a
  # shellcheck disable=SC1090
  . "${ENV_FILE:-/config/.env}"
  set +a
fi

exec "$@"
