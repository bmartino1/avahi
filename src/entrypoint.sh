#!/bin/bash -e

if [ "${DEBUG}" == "true" ]; then
  set -x
fi

AUG_BASE="/etc/avahi/avahi-daemon.conf"

avahi_set() {
  if [ $# -lt 3 ]; then
    >&2 echo "Usage: avahi_set SECTION KEY VALUE"
    return 1
  fi
  augtool set "${AUG_BASE}/$1/$2" "$3"
}

# Default settings
SERVER_ENABLE_DBUS=${SERVER_ENABLE_DBUS:-no}

# Configure Avahi settings using environment variables
configure_section() {
  local section=$1
  local keys=($(env | grep "^${section}_" | cut -d= -f1))
  for key in "${keys[@]}"; do
    local value=${!key}
    local option=$(echo "$key" | sed "s/^${section}_//" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    avahi_set "$section" "$option" "$value"
  done
}

configure_section "SERVER"
configure_section "WIDE_AREA"
configure_section "PUBLISH"
configure_section "REFLECTOR"
configure_section "RLIMITS"

# Cleanup stale PID file if it exists
PID_FILE="/var/run/avahi-daemon/pid"
if [ -f "${PID_FILE}" ]; then
  AVAHI_PID=$(cat "${PID_FILE}")
  if [ -z "${AVAHI_PID}" ] || ! kill -0 "${AVAHI_PID}" 2>/dev/null; then
    >&2 echo "Cleaning up stale PID file: ${PID_FILE}"
    rm -f "${PID_FILE}"
  fi
fi

# Execute the provided command or run avahi-daemon by default
if [ $# -eq 0 ] || [[ "$1" == -* ]]; then
  exec avahi-daemon "$@"
else
  exec "$@"
fi
