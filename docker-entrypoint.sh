#!/bin/sh
set -eu
configured_runtime_dir="${RUNTIME_DIR:-/config}"
configured_env_file="${ENV_FILE:-${configured_runtime_dir}/.env}"
trim_with_sed() {
  printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}
load_env_file() {
  file_path="$1"
  loaded_keys=0
  invalid_lines=0
  while IFS= read -r raw_line || [ -n "${raw_line}" ]; do
    line=$(printf '%s' "${raw_line}" | tr -d '\r')
    line=$(trim_with_sed "${line}")
    [ -n "${line}" ] || continue
    case "${line}" in
      \#*)
        continue
        ;;
    esac
    case "${line}" in
      export[[:space:]]*)
        line=$(trim_with_sed "${line#export}")
        ;;
    esac
    case "${line}" in
      *=*)
        key=$(trim_with_sed "${line%%=*}")
        value="${line#*=}"
        value=$(trim_with_sed "${value}")
        ;;
      *)
        invalid_lines=$((invalid_lines + 1))
        continue
        ;;
    esac
    case "${key}" in
      [A-Za-z_][A-Za-z0-9_]*)
        ;;
      *)
        invalid_lines=$((invalid_lines + 1))
        continue
        ;;
    esac
    value=$(printf '%s' "${value}" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    export "${key}=${value}"
    loaded_keys=$((loaded_keys + 1))
  done <"${file_path}"
  echo "Loaded ${loaded_keys} env var(s) from ${file_path}"
  if [ "${invalid_lines}" -gt 0 ]; then
    echo "Skipped ${invalid_lines} invalid line(s) in ${file_path}; expected KEY=VALUE format." >&2
  fi
}
env_file=""
checked_paths=""
seen_paths="|"
for candidate in "${configured_env_file}" "${configured_runtime_dir}/.env" "/config/.env" "/workspace/.env"; do
  [ -n "${candidate}" ] || continue
  case "${seen_paths}" in
    *"|${candidate}|"*)
      continue
      ;;
  esac
  seen_paths="${seen_paths}${candidate}|"
  if [ -n "${checked_paths}" ]; then
    checked_paths="${checked_paths}, ${candidate}"
  else
    checked_paths="${candidate}"
  fi
  if [ -f "${candidate}" ]; then
    if [ -r "${candidate}" ]; then
      env_file="${candidate}"
      break
    fi
    echo "Found .env at ${candidate}, but it is not readable by $(id -u):$(id -g); skipping it." >&2
  fi
done
if [ -n "${env_file}" ]; then
  echo "Loading environment from ${env_file}"
  load_env_file "${env_file}"
else
  echo "No readable .env file found (checked: ${checked_paths}); relying on Docker env vars." >&2
fi
umask "${UMASK:-002}"
: "${REDIS_ENABLED:=true}"
: "${ENABLE_REDIS_CACHE:=true}"
: "${USE_REDIS_CACHE:=true}"
export REDIS_ENABLED ENABLE_REDIS_CACHE USE_REDIS_CACHE
ensure_writable_dir() {
  dir="$1"
  if [ ! -d "${dir}" ]; then
    mkdir -p "${dir}" 2>/dev/null || return 1
  fi
  [ -w "${dir}" ] || return 1
  probe_file="${dir}/.writable.$$"
  if ! touch "${probe_file}" 2>/dev/null; then
    return 1
  fi
  rm -f "${probe_file}" 2>/dev/null || true
  return 0
}
runtime_dir="${RUNTIME_DIR:-/config}"
if ! ensure_writable_dir "${runtime_dir}"; then
  fallback_runtime_dir="/tmp/maverick-mcp"
  mkdir -p "${fallback_runtime_dir}"
  runtime_dir="${fallback_runtime_dir}"
  echo "Runtime directory ${RUNTIME_DIR:-/config} is not writable for $(id -u):$(id -g); using ${runtime_dir}" >&2
fi
cd "${runtime_dir}"
home_dir="${HOME:-${runtime_dir}}"
if ! ensure_writable_dir "${home_dir}"; then
  fallback_home_dir="${runtime_dir}"
  if ! ensure_writable_dir "${fallback_home_dir}"; then
    fallback_home_dir="/tmp/maverick-mcp-home"
    mkdir -p "${fallback_home_dir}"
  fi
  home_dir="${fallback_home_dir}"
  echo "HOME path ${HOME:-${runtime_dir}} is not writable; using ${home_dir}" >&2
fi
export HOME="${home_dir}"
xdg_cache_home="${XDG_CACHE_HOME:-${HOME}/.cache}"
if ! ensure_writable_dir "${xdg_cache_home}"; then
  fallback_xdg_cache_home="/tmp/.cache"
  mkdir -p "${fallback_xdg_cache_home}"
  xdg_cache_home="${fallback_xdg_cache_home}"
  echo "XDG cache path ${XDG_CACHE_HOME:-${HOME}/.cache} is not writable; using ${fallback_xdg_cache_home}" >&2
fi
export XDG_CACHE_HOME="${xdg_cache_home}"
numba_cache_dir="${NUMBA_CACHE_DIR:-${runtime_dir}/.numba_cache}"
if ! ensure_writable_dir "${numba_cache_dir}"; then
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
