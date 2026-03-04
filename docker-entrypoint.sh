#!/bin/sh
set -eu

if [ -f "${ENV_FILE:-/config/.env}" ]; then
  echo "Loading environment from ${ENV_FILE:-/config/.env}"
  set -a
  # shellcheck disable=SC1090
  . "${ENV_FILE:-/config/.env}"
  set +a
fi

exec "$@"
